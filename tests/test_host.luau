--!strict
-- The block end to end: host.luau under a stub runtime, reading the fixture database through the real sqlite3.
local check = require("./check")
local fixture = require("./fixture")
local stub = require("./tern_stub")

local ROOT = "."

local function texts(node: any, out: { string }?): string
	local acc = out or {}
	if type(node) == "string" then
		table.insert(acc, node)
	elseif type(node) == "table" then
		for _, v in node do
			texts(v, acc)
		end
	end
	return table.concat(acc, "\n")
end


local function key(name: string): any
	return { name = name, ctrl = false, alt = false, meta = false, shift = false }
end


local function open(home: string, saved: any?)
	local h = stub.host(ROOT, home, { { pane = 1 } })
	local def = h.blocks.dashboard
	local cx = {
		pane = 1,
		cols = 120,
		rows = 40,
		rendered = 0,
		saved = 0,
		render = function(self: any)
			self.rendered += 1
		end,
		save = function(self: any)
			self.saved += 1
		end,
	}
	local state = def.init(cx, {}, saved)
	return h, def, cx, state
end

local function shown(def: any, state: any, cx: any): string
	local v = def.view(state, cx)
	return texts(v.main) .. "\n" .. texts(v.dock) .. "\n" .. def.title(state)
end

local home = fixture.home()

-- First load: default tab and period (overview, 7 d). Nothing is queried before init returned.
local h, def, cx, state = open(home)
check.has(shown(def, state, cx), "Chargement", "shows a loading state before the first answer")
h.flush()
local page = shown(def, state, cx)
check.has(page, "$7.00", "7d overview: cost of A+B+C")
check.has(page, "Taux d'erreur", "overview KPIs")
check.has(page, "vs période préc.", "KPI deltas against the previous window (D)")
check.eq(#h.logs, 0, "no render failure logged")
check.has(page, "dernière requête omp", "footer says how fresh the data is")

-- The 30 s timer queries again, and keeps polling.
local before = h.spawned
h.tick()
check.eq(h.spawned > before, true, "poll refreshes the active tab")
before = h.spawned
h.tick()
check.eq(h.spawned > before, true, "poll re-arms itself")

-- Period keys: 1 = 24 h. Answers are applied only for the active period.
check.eq(def.key(state, key("1"), cx), true, "key 1 handled")
h.flush()
check.has(shown(def, state, cx), "$3.00", "24h overview cost")
check.has(shown(def, state, cx), "pic $2.00", "trend caption names the peak hour (B, $2.00)")
check.has(shown(def, state, cx), "Cache écrit", "token mix is a labelled table")
check.eq(def.key(state, key("1"), cx), false, "re-selecting the active period changes nothing")
check.eq(def.key(state, key("z"), cx), false, "unknown key is not consumed")
check.eq(def.key(state, { name = "1", ctrl = true, alt = false, meta = false, shift = false }, cx), false, "ctrl+1 is not ours")

-- Tabs by key and by click event.
def.key(state, key("right"), cx)
h.flush()
local models = shown(def, state, cx)
check.has(models, "m1", "models tab lists m1")
check.has(models, "Modèles", "models tab title")
def.event(state, { ev = "action", act = "tab", value = "tools" }, cx)
h.flush()
check.has(shown(def, state, cx), "bash", "tools tab lists bash")
check.eq(cx.saved > 0, true, "tab change is persisted")
def.event(state, { ev = "action", act = "range", value = "30d" }, cx)
h.flush()
check.has(shown(def, state, cx), "Outils distincts", "tools KPIs on 30d")
check.eq(def.save(state), { tab = "tools", range = "30d" }, "state saved")
for _, tab in { "performance", "projects", "sessions", "overview" } do
	def.event(state, { ev = "action", act = "tab", value = tab }, cx)
	h.flush()
end
check.eq(#h.logs, 0, "every tab renders")
check.has(shown(def, state, cx), "Coût", "back to overview")
def.key(state, key("left"), cx)
check.has(shown(def, state, cx), "OMP Stats · Sessions", "left wraps to the previous tab")

-- Cached data stays on screen while a refresh runs.
h.hold = true
def.key(state, key("r"), cx)
local during = shown(def, state, cx)
check.has(during, "actualisation", "footer shows the refresh")
check.has(during, "Sessions récentes", "previous data stays while refreshing")
h.hold = false
h.release()
check.lacks(shown(def, state, cx), "actualisation", "refresh indicator clears")

-- A slow answer for a period the user already left must neither end the newer query's loading state
-- nor show its own failure.
h.hold = true
def.event(state, { ev = "action", act = "tab", value = "overview" }, cx)
h.release() -- settle whatever is in flight
h.fail_with = "boom: stale 24h query"
def.event(state, { ev = "action", act = "range", value = "24h" }, cx) -- held 1-4, the first one fails
def.event(state, { ev = "action", act = "range", value = "90d" }, cx) -- held 5-8
h.release({ 1, 2, 3, 4 }) -- the stale answers land while 90 d is still loading
local mid = shown(def, state, cx)
check.has(mid, "actualisation", "newer query still shown as loading")
check.lacks(mid, "boom", "stale failure is not shown")
h.release() -- the 90 d answers, still held
h.hold = false
local latest = shown(def, state, cx)
check.has(latest, "90 j", "90d is the active period")
check.has(latest, "$15.00", "90d cost A+B+C+D")
check.lacks(latest, "boom", "no error after the newer query succeeded")

-- Persisted state is restored, and a bogus one falls back to the defaults.
local _h2, def2, cx2, state2 = open(home, { tab = "models", range = "24h" })
check.has(def2.title(state2), "Modèles · 24 h", "restored tab and period")
local _h3, def3, cx3, state3 = open(home, { tab = "nope", range = "1y" })
check.has(def3.title(state3), "Vue d'ensemble · 7 j", "unknown saved values fall back")
local _ = { cx2, cx3 }

-- Errors: sqlite failure keeps the last data and says why; a missing database says where it looked.
local h4, def4, cx4, state4 = open(home)
h4.flush()
h4.fail_with = "Error: database is locked"
def4.key(state4, key("r"), cx4)
local failed = shown(def4, state4, cx4)
check.has(failed, "database is locked", "sqlite error shown")
check.has(failed, "$7.00", "last good data kept on a failed refresh")
fixture.remove(home)

local empty = fixture.empty_home()
local h5, def5, cx5, state5 = open(empty)
h5.flush()
local missing = shown(def5, state5, cx5)
check.has(missing, "Base introuvable", "missing database explained")
check.has(missing, empty .. "/.omp/stats.db", "with the path it looked at")
fixture.remove(empty)

-- A pane that is gone stops the block: no timers, no answers applied.
local gone = fixture.home()
local panes = { { pane = 1 } }
local h6 = stub.host(ROOT, gone, panes)
local def6 = h6.blocks.dashboard
local cx6 = { pane = 1, cols = 100, rows = 30, render = function() end, save = function() end }
local state6 = def6.init(cx6, {}, nil)
table.remove(panes, 1)
h6.flush()
check.eq(state6.cache, {}, "closed pane: nothing loaded")
fixture.remove(gone)

-- Language: the block switches with `g`, the palette command (window half) switches it and tells open blocks.
local lhome = fixture.home()
local lh = stub.host(ROOT, lhome, { { pane = 1 } }) -- French locale
local ldef = lh.blocks.dashboard
local lcx = { pane = 1, cols = 120, rows = 40, render = function() end, save = function() end }
local lstate = ldef.init(lcx, {}, nil)
lh.flush()
local french = shown(ldef, lstate, lcx)
check.has(french, "Vue d'ensemble", "French by locale")
check.has(french, "Coût", "French KPIs")
check.has(french, "g langue", "the footer names the language key")
check.eq(ldef.key(lstate, key("g"), lcx), true, "g is handled")
lh.flush()
check.eq(lh.kv.lang, "en", "g saves the new language")
local english = shown(ldef, lstate, lcx)
check.has(english, "OMP Stats · Overview · 7 d", "English pane title and period")
check.has(english, "Cost", "English KPIs")
check.has(english, "vs prev. period", "English deltas")
check.has(english, "latest omp request", "English footer")
check.has(english, "g language", "English key hints")

-- Every tab and period shows one language only: words of the other language never appear.
local FRENCH = { "Appels", "Coût", "Requêtes", "Taux", "Outils", "Durée", "Débit", "Entrée", "Sortie", "Projet", "Début", "Économie", "économie", "Chargement", "Aucun", "Dernière", "période", "Modèle", "actualis", "langue" }
local ENGLISH = { "Cost", "Calls", "Requests", "Failure", "Duration", "Speed", "Input", "Output", "Share", "Project", "Start", "Saving", "saved $", "Loading", "No omp", "Last req", "period", "Avg", "refreshing", "language" }
local function sweep(words: { string }, label: string)
	for _, range in { "24h", "7d", "30d", "90d" } do
		for _, tab in { "overview", "models", "projects", "performance", "tools", "sessions" } do
			ldef.event(lstate, { ev = "action", act = "range", value = range }, lcx)
			ldef.event(lstate, { ev = "action", act = "tab", value = tab }, lcx)
			lh.flush()
			local page = shown(ldef, lstate, lcx)
			for _, word in words do
				check.lacks(page, word, `{label} {tab} {range}`)
			end
		end
	end
end
sweep(FRENCH, "English")
check.eq(#lh.logs, 0, "every tab renders in English")
ldef.event(lstate, { ev = "action", act = "lang", value = "toggle" }, lcx) -- the button
lh.flush()
check.eq(lh.kv.lang, "fr", "the button toggles back")
sweep(ENGLISH, "French")
check.eq(#lh.logs, 0, "every tab renders in French")

local toasts: { string } = {}
local told: { { any } } = {}
local wcx = {
	toast = function(_: any, _level: string, text: string)
		table.insert(toasts, text)
	end,
	session = {
		panes = function()
			return {
				{ pane = 1, title = "OMP Stats · Vue d'ensemble · 7 j" },
				{ pane = 2, kind = "terminal", title = "OMP Stats notes" },
				{ pane = 3, title = "Tracker" },
			}
		end,
		event = function(_: any, pane: number, ev: any)
			table.insert(told, { pane, ev.act })
		end,
	},
}
check.eq(lh.commands.lang.title, "Changer de langue (FR/EN)", "palette command in French")
lh.commands.lang.run(wcx)
check.eq(lh.kv.lang, "en", "the command switches the saved language")
check.eq({ toasts[1], told }, { "Language: English", { { 1, "lang" } } }, "toast, and only the OMP Stats block is told")
check.eq(lh.commands.lang.title, "Switch language (FR/EN)", "palette command re-registered in English")
ldef.event(lstate, { ev = "action", act = "lang" }, lcx) -- what the block receives
lh.flush()
check.eq(lh.kv.lang, "en", "the notification redraws without toggling again")
check.has(shown(ldef, lstate, lcx), "Sessions", "block shows the new language")
fixture.remove(lhome)

-- Without a saved choice the locale decides: fr* is French, anything else English.
local locales = { { "fr_FR.UTF-8", "fr" }, { "fr_BE", "fr" }, { "en_US.UTF-8", "en" }, { "C", "en" }, { "de_DE", "en" } }
for _, pair in locales do
	local lang = stub.host(ROOT, "/nonexistent", {}, pair[1]).require("lib/i18n").lang()
	check.eq(lang, pair[2], `locale {pair[1]}`)
end
