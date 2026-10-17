--!strict
-- A stand-in for Tern's host runtime, enough to run host.luau for real: `tern.ui` builds plain nodes,
-- `tern.process.run` shells out to the actual sqlite3 (so the block reads the fixture database end to end),
-- timers and pane lists are driven by the test.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local stub = {}

export type Harness = {
	tern: any,
	-- Block definitions registered by the plugin, by block id.
	blocks: { [string]: any },
	-- Fires the zero-delay timers until none is left.
	flush: () -> (),
	-- Fires the long (poll) timers once, then the zero-delay ones.
	tick: () -> (),
	-- How many sqlite3 processes the block started.
	spawned: number,
	-- Deferred mode: process callbacks are held until `release` runs them (oldest first).
	hold: boolean,
	release: (order: { number }?) -> (),
	-- Makes the next process result fail with this stderr.
	fail_with: string?,
	logs: { string },
	-- The plugin's `tern.kv` store, and the palette commands its window half registered (by id).
	kv: { [string]: any },
	commands: { [string]: any },
	-- A plugin module by path under the plugin root ("lib/parts"), sharing the block's runtime and cache.
	require: (path: string) -> any,
}

local function nodes()
	local ui: { [string]: any } = {}
	local function make(kind: string)
		return function(...: any)
			return { k = kind, a = { ... } }
		end
	end
	for _, kind in { "text", "col", "lines", "row", "card", "section", "rule", "badge", "kv", "table", "meter_cell", "tree", "list", "code", "diff", "md", "meter", "progress", "bars", "spark", "el" } do
		ui[kind] = make(kind)
	end
	ui.span = function(t: string, s: string?)
		return { t = t, s = s }
	end
	return ui
end

--- Loads `<root>/<path>` with `tern` injected; `require("./x")` resolves against the requiring file.
function stub.loader(root: string, tern: any)
	local cache: { [string]: any } = {}
	local function load(path: string): any
		if cache[path] ~= nil then
			return cache[path]
		end
		local source = fs.readFile(path)
		local dir = string.match(path, "^(.*)/[^/]+$") or "."
		local function req(rel: string): any
			local target = string.gsub(rel, "^%./", dir .. "/")
			return load(target .. ".luau")
		end
		local chunk = luau.load(luau.compile(source), { environment = { tern = tern, require = req } })
		local value = chunk()
		cache[path] = if value == nil then true else value
		return cache[path]
	end
	return load, root
end

--- Runs host.luau under the stub with `home` as $HOME. `panes` is the live pane list.
function stub.host(root: string, home: string, panes: { { pane: number } }, locale: string?): Harness
	local locale = locale or "fr_FR.UTF-8"
	local timers: { { ms: number, fire: () -> () } } = {}
	local held: { () -> () } = {}
	local h: Harness = {
		tern = nil,
		blocks = {},
		flush = function() end,
		tick = function() end,
		spawned = 0,
		hold = false,
		release = function() end,
		fail_with = nil,
		logs = {},
		kv = {},
		commands = {},
		require = function(): any
			return nil
		end,
	}
	local tern = {
		ui = nodes(),
		json = {
			decode = function(text: string): any
				return require("@lune/serde").decode("json", text)
			end,
		},
		getenv = function(name: string): string?
			if name == "HOME" then
				return home
			end
			return if name == "LANG" then locale else nil
		end,
		kv = {
			get = function(key: string): any
				return h.kv[key]
			end,
			set = function(key: string, value: any)
				h.kv[key] = value
			end,
		},
		command = function(def: any)
			h.commands[def.id] = def
		end,
		fs = {
			exists = function(path: string): boolean
				return fs.isFile(path)
			end,
		},
		pane = {
			list = function()
				return panes
			end,
		},
		timer = function(ms: number, fn: () -> ())
			local entry = { cancelled = false }
			table.insert(timers, {
				ms = ms,
				fire = function()
					if not entry.cancelled then
						fn()
					end
				end,
			})
			return {
				cancel = function()
					entry.cancelled = true
				end,
			}
		end,
		log = {
			error = function(...: any)
				table.insert(h.logs, table.concat({ ... } :: any, " "))
			end,
		},
		block = {
			define = function(id: string, def: any)
				h.blocks[id] = def
			end,
		},
		process = {
			run = function(argv: { string }, _opts: any, cb: (any, any) -> ())
				h.spawned += 1
				local result
				if h.fail_with then
					result = { status = 1, stdout = "", stderr = h.fail_with, timed_out = false }
					h.fail_with = nil
				else
					local program = table.remove(argv, 1) :: string
					local exec = process.exec(program, argv)
					result = { status = exec.code, stdout = exec.stdout, stderr = exec.stderr, timed_out = false }
				end
				local run = function()
					cb(result, nil)
				end
				if h.hold then
					table.insert(held, run)
				else
					run()
				end
			end,
		},
	}
	h.tern = tern
	-- Fires the zero-delay timers (what `tern.timer(0, …)` schedules), until none is left.
	h.flush = function()
		local fired = true
		while fired do
			fired = false
			for i = #timers, 1, -1 do
				local timer = timers[i]
				if timer.ms == 0 then
					table.remove(timers, i)
					timer.fire()
					fired = true
				end
			end
		end
	end
	-- Fires the long timers (the 30 s poll) once.
	h.tick = function()
		local batch = timers
		timers = {}
		for _, timer in batch do
			timer.fire()
		end
		h.flush()
	end
	-- Runs the held callbacks at `order` (all of them, oldest first, when nil); the others stay held.
	h.release = function(order: { number }?)
		local batch = held
		held = {}
		local indexes: { number } = order or {}
		if not order then
			for i = 1, #batch do
				table.insert(indexes, i)
			end
		end
		local ran: { [number]: boolean } = {}
		for _, i in indexes do
			ran[i] = true
			batch[i]()
		end
		for i, run in batch do
			if not ran[i] then
				table.insert(held, run)
			end
		end
	end
	local load = stub.loader(root, tern)
	load(root .. "/host.luau")
	load(root .. "/window.luau")
	h.require = function(path: string): any
		return load(root .. "/" .. path .. ".luau")
	end
	return h
end

return stub
