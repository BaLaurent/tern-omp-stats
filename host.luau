--!strict
-- OMP Stats: a dashboard of ~/.omp/stats.db in a Tern block.
--
-- Keys: 1-4 period, ←/→ (h/l, tab) tab, r refresh. Mouse: click a period or a tab.
-- Only the active tab is queried (see lib/queries.luau); results are cached per tab and period so that
-- switching back shows the last data at once while a fresh query runs.

local db = require("./lib/db")
local fmt = require("./lib/fmt")
local queries = require("./lib/queries")
local ranges = require("./lib/ranges")

local ui = tern.ui

local POLL_MS = 30 * 1000

type Tab = {
	id: string,
	label: string,
	queries: (ranges.Range) -> queries.Queries,
	render: ({ [string]: { any } }, ranges.Range, number) -> Node,
}

local TABS: { Tab } = {
	{ id = "overview", label = "Vue d'ensemble", queries = queries.overview, render = require("./lib/view_overview").render },
	{ id = "models", label = "Modèles", queries = queries.models, render = require("./lib/view_models").render },
	{ id = "projects", label = "Projets", queries = queries.projects, render = require("./lib/view_projects").render },
	{ id = "performance", label = "Performance", queries = queries.performance, render = require("./lib/view_performance").render },
	{ id = "tools", label = "Outils", queries = queries.tools, render = require("./lib/view_tools").render },
	{ id = "sessions", label = "Sessions", queries = queries.sessions, render = require("./lib/view_sessions").render },
}

type State = {
	cx: BlockCx,
	tab: number,
	range: ranges.Range,
	cache: { [string]: { [string]: { any } } },
	-- Bumped by every load; an answer for an older load is dropped.
	gen: number,
	loading: boolean,
	err: string?,
	timer: TimerHandle?,
	last_ts: number?,
	db_now: number?,
}

-- One state per pane: a block that re-inits retires the previous one (stops its timer, drops its answers).
local running: { [number]: State } = {}

local function retire(state: State)
	if running[state.cx.pane] == state then
		running[state.cx.pane] = nil
	end
	if state.timer then
		state.timer:cancel()
		state.timer = nil
	end
	state.gen += 1
end

local function alive(state: State): boolean
	if running[state.cx.pane] ~= state then
		return false
	end
	for _, pane in tern.pane.list() do
		if pane.pane == state.cx.pane then
			return true
		end
	end
	retire(state)
	return false
end

local function key_of(state: State): string
	return TABS[state.tab].id .. "|" .. state.range.id
end

-- Queries the active tab and period. `quiet`: no render until the answer lands (used by init, which
-- cannot render before it returns its state).
local function load(state: State, quiet: boolean?)
	if not alive(state) then
		return
	end
	state.gen += 1
	local gen = state.gen
	local key = key_of(state)
	local tab, range = TABS[state.tab], state.range
	if not db.exists() then
		state.err = `Base introuvable : {db.path()}. Lancez une fois « omp stats » pour la créer.`
		state.loading = false
		if not quiet then
			state.cx:render()
		end
		return
	end
	state.loading = true
	if not quiet then
		state.cx:render()
	end
	db.run(tab.queries(range), function(results, err)
		if not alive(state) or gen ~= state.gen then
			return
		end
		state.loading = false
		if results then
			state.cache[key] = results
			state.err = nil
			local clock = (results.meta or {})[1]
			if clock then
				state.last_ts = if type(clock.last_ts) == "number" then clock.last_ts else nil
				state.db_now = if type(clock.now) == "number" then clock.now else nil
			end
		else
			state.err = err
		end
		state.cx:render()
	end)
end

local function poll(state: State)
	if not alive(state) or state.timer then
		return
	end
	state.timer = tern.timer(POLL_MS, function()
		if not alive(state) then
			return
		end
		state.timer = nil
		load(state)
		poll(state)
	end)
end

local function select_tab(state: State, index: number)
	state.tab = ((index - 1) % #TABS) + 1
	state.err = nil
	load(state)
end

local function select_range(state: State, id: string): boolean
	local range = ranges.find(id)
	if not range or range == state.range then
		return false
	end
	state.range = range
	state.err = nil
	load(state)
	return true
end

local function tab_index(id: string): number?
	for i, tab in TABS do
		if tab.id == id then
			return i
		end
	end
	return nil
end

local function button(label: string, act: string, on: boolean): Node
	return ui.el("button", {
		class = if on then "os-btn on" else "os-btn",
		actions = { click = act },
		text = label,
	})
end

local function header(state: State): Node
	local tabs: { Node } = {}
	for i, tab in TABS do
		table.insert(tabs, button(tab.label, "tab=" .. tab.id, i == state.tab))
	end
	local periods: { Node } = {}
	for _, r in ranges.list do
		table.insert(periods, button(r.label, "range=" .. r.id, r == state.range))
	end
	return ui.el("div", { class = "os-bar" }, {
		ui.el("span", { class = "os-title", text = "OMP Stats" }),
		ui.el("div", { class = "os-group" }, tabs),
		ui.el("div", { class = "os-group" }, periods),
		button("↻", "refresh=1", false),
	})
end

local function body(state: State, cols: number): Node
	local data = state.cache[key_of(state)]
	if data then
		local ok, node = pcall(TABS[state.tab].render, data, state.range, cols)
		if ok then
			return node :: Node
		end
		tern.log.error("omp-stats render failed", tostring(node))
		return ui.text({ ui.span("Affichage impossible : " .. tostring(node), "error") })
	end
	if state.err then
		return ui.text({ ui.span(state.err, "error") })
	end
	return ui.progress(nil, "Chargement des statistiques…")
end

local function footer(state: State): Node
	local spans: { Span | string } = {}
	if state.loading then
		table.insert(spans, ui.span("⟳ actualisation  ·  ", "muted"))
	end
	if state.err and state.cache[key_of(state)] then
		table.insert(spans, ui.span("dernière actualisation en échec : " .. state.err .. "  ·  ", "error"))
	end
	if state.last_ts and state.db_now then
		table.insert(spans, ui.span("dernière requête omp " .. fmt.ago(state.db_now - state.last_ts) .. "  ·  ", "muted"))
	end
	table.insert(spans, ui.span("1-4 période  ←/→ onglet  r actualiser", "muted"))
	return ui.col({ ui.text(spans) })
end

tern.block.define("dashboard", {
	init = function(cx: BlockCx, _args: { string }, saved: any): State
		local previous = running[cx.pane]
		if previous then
			retire(previous)
		end
		local tab, range = 1, ranges.list[2]
		if type(saved) == "table" then
			tab = tab_index(tostring(saved.tab)) or tab
			range = ranges.find(saved.range) or range
		end
		local state: State = {
			cx = cx,
			tab = tab,
			range = range,
			cache = {},
			gen = 0,
			loading = false,
			err = nil,
			timer = nil,
			last_ts = nil,
			db_now = nil,
		}
		running[cx.pane] = state
		-- Load after init has returned, so the first render sees a registered state.
		tern.timer(0, function()
			load(state)
			poll(state)
		end)
		return state
	end,

	view = function(state: State, cx: BlockCx): BlockView
		return {
			main = ui.col({ header(state), body(state, cx.cols) }),
			dock = footer(state),
		}
	end,

	title = function(state: State): string?
		return `OMP Stats · {TABS[state.tab].label} · {state.range.label}`
	end,

	key = function(state: State, key: Key, _cx: BlockCx): boolean?
		if key.ctrl or key.alt or key.meta then
			return false
		end
		local name = key.name
		for _, r in ranges.list do
			if name == r.key then
				return select_range(state, r.id)
			end
		end
		if name == "right" or name == "l" or name == "tab" then
			select_tab(state, state.tab + 1)
		elseif name == "left" or name == "h" then
			select_tab(state, state.tab - 1)
		elseif name == "r" or name == "f5" then
			load(state)
		else
			return false
		end
		return true
	end,

	event = function(state: State, ev: UiEvent, cx: BlockCx)
		if ev.ev ~= "action" or type(ev.act) ~= "string" then
			return
		end
		local value = ev.value
		if ev.act == "tab" and type(value) == "string" then
			local index = tab_index(value)
			if index then
				select_tab(state, index)
			end
		elseif ev.act == "range" and type(value) == "string" then
			select_range(state, value)
		elseif ev.act == "refresh" then
			load(state)
		else
			return
		end
		cx:save()
	end,

	save = function(state: State): any
		return { tab = TABS[state.tab].id, range = state.range.id }
	end,
})
