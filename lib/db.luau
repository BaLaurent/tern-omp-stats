--!strict
-- Runs read-only SQL against omp's stats database. The `tern.db` API only exists in the window half, and
-- a block lives in the host half, so statements go through the `sqlite3` CLI (`-readonly -json`).

local i18n = require("./i18n")

local db = {}

local SQLITE = { "sqlite3", "/usr/bin/sqlite3", "/usr/local/bin/sqlite3", "/opt/homebrew/bin/sqlite3" }
-- A cold page cache needs ~20 s for the widest tool-call scan; leave generous room.
local TIMEOUT_MS = 120 * 1000

function db.path(): string
	return (tern.getenv("HOME") or "") .. "/.omp/stats.db"
end

function db.exists(): boolean
	return tern.fs.exists(db.path())
end

--- Spawns the first `sqlite3` that exists; `done` gets the process result. Returns an error text on failure.
local function spawn(sql: string, done: (ProcessResult) -> ()): string?
	local argv: { string } = { "", "-readonly", "-cmd", ".timeout 3000", "-json", db.path(), sql }
	local last = i18n.t("err_no_sqlite")
	for _, bin in SQLITE do
		argv[1] = bin
		local ok, err = pcall(function()
			tern.process.run(argv, { timeout_ms = TIMEOUT_MS }, function(result: ProcessResult, _)
				done(result)
			end)
		end)
		if ok then
			return nil
		end
		last = tostring(err)
	end
	return last
end

local function decode(result: ProcessResult): ({ any }?, string?)
	if result.timed_out then
		return nil, i18n.t("err_timeout")
	end
	if result.status ~= 0 then
		local msg = string.gsub(result.stderr, "%s+$", "")
		return nil, if msg == "" then i18n.tf("err_failed", result.status) else msg
	end
	if string.match(result.stdout, "^%s*$") then
		return {}, nil
	end
	local ok, rows = pcall(tern.json.decode, result.stdout)
	if not ok or type(rows) ~= "table" then
		return nil, i18n.t("err_unreadable")
	end
	return rows, nil
end

--- Runs every statement of `sqls` concurrently. `cb` fires once, after all finished: the rows of each
--- statement by name, or nil and the first error.
function db.run(sqls: { [string]: string }, cb: ({ [string]: { any } }?, string?) -> ())
	local pending = 0
	for _ in sqls do
		pending += 1
	end
	local results: { [string]: { any } } = {}
	local failure: string? = nil
	local function settle()
		pending -= 1
		if pending > 0 then
			return
		end
		if failure then
			cb(nil, failure)
		else
			cb(results, nil)
		end
	end
	if pending == 0 then
		cb(results, nil)
		return
	end
	for name, sql in sqls do
		local err = spawn(sql, function(result)
			local rows, problem = decode(result)
			if rows then
				results[name] = rows
			elseif not failure then
				failure = `{name}: {problem}`
			end
			settle()
		end)
		if err then
			failure = failure or err
			settle()
		end
	end
end

return db
