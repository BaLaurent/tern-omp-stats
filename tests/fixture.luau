--!strict
-- A throwaway stats database shaped like omp's (only the columns the dashboard reads), with rows placed
-- relative to "now" so every period has known content:
--   A  -2h  m1 /proj-a/ main      s1  cost 1.0  ok      ttft 400  duration 2000  50 out tokens
--   B  -3h  m2 /proj-b/ subagent  s2  cost 2.0  error   ttft 600  duration 0
--   C  -26h m1 /proj-a/ main      s3  cost 4.0  ok      (previous window of 24h, current of 7d)
--   D  -10d m1 /proj-a/ main      s4  cost 8.0  ok      unpriced (previous window of 7d, current of 30d)

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local fixture = {}

local NOW = "CAST(strftime('%s','now') AS INTEGER)*1000"

-- `@<n>@` stands for "n hours before now" in epoch milliseconds.
local SETUP_TEMPLATE = [[
CREATE TABLE messages (timestamp INTEGER, model TEXT, provider TEXT, folder TEXT, agent_type TEXT, session_file TEXT,
	input_tokens INTEGER, output_tokens INTEGER, cache_read_tokens INTEGER, cache_write_tokens INTEGER, total_tokens INTEGER,
	cost_total REAL, cost_input REAL, cost_cache_read REAL, cost_cache_write REAL, cost_no_cache_input REAL,
	cost_unpriced INTEGER, stop_reason TEXT, ttft REAL, duration REAL);
CREATE INDEX idx_messages_timestamp ON messages(timestamp);
CREATE TABLE tool_calls (timestamp INTEGER, tool_name TEXT, is_error INTEGER, args_chars INTEGER, result_chars INTEGER);
CREATE TABLE user_messages (timestamp INTEGER);
CREATE INDEX idx_messages_model ON messages(model);
CREATE INDEX idx_messages_folder ON messages(folder);
CREATE INDEX idx_messages_session ON messages(session_file);
CREATE INDEX idx_tool_calls_timestamp ON tool_calls(timestamp);
CREATE INDEX idx_tool_calls_tool_timestamp ON tool_calls(tool_name, timestamp);
CREATE INDEX idx_user_messages_timestamp ON user_messages(timestamp);
INSERT INTO messages VALUES
 (@2@,'m1','p','/proj-a/','main','s1',100,50,1000,10,1160,1.0,0.1,0.2,0.3,5.0,0,'stop',400,2000),
 (@3@,'m2','p','/proj-b/','subagent','s2',10,0,0,0,10,2.0,0,0,0,0.5,0,'error',600,0),
 (@26@,'m1','p','/proj-a/','main','s3',200,100,0,0,300,4.0,0,0,0,4.0,0,'stop',NULL,NULL),
 (@240@,'m1','p','/proj-a/','main','s4',1,1,0,0,2,8.0,0,0,0,0,1,'stop',100,1000);
INSERT INTO tool_calls VALUES
 (@2@,'bash',0,100,1000),(@2@,'bash',1,200,2000),(@3@,'bash',0,300,3000),
 (@2@,'read',0,10,100),(@240@,'bash',0,50,500);
INSERT INTO user_messages VALUES (@2@),(@3@),(@26@);
]]

local SETUP = string.gsub(SETUP_TEMPLATE, "@(%d+)@", function(hours: string): string
	return `({NOW} - {hours} * 3600000)`
end)

--- Runs one statement through the sqlite3 CLI the way the plugin does; returns the decoded rows.
function fixture.query(db: string, sql: string): { any }
	local result = process.exec("sqlite3", { "-readonly", "-json", db, sql })
	assert(result.ok, "sqlite3 failed: " .. result.stderr .. "\n" .. sql)
	if string.match(result.stdout, "^%s*$") then
		return {}
	end
	return serde.decode("json", result.stdout)
end

--- The query plan SQLite chose for `sql`, as text.
function fixture.plan(db: string, sql: string): string
	local result = process.exec("sqlite3", { "-readonly", db, "EXPLAIN QUERY PLAN " .. sql })
	assert(result.ok, "sqlite3 failed: " .. result.stderr)
	return result.stdout
end

--- Runs statements that change the fixture database (the plugin itself never writes).
function fixture.exec(db: string, sql: string)
	local result = process.exec("sqlite3", { db, sql })
	assert(result.ok, "sqlite3 failed: " .. result.stderr)
end

--- A temporary HOME holding `.omp/stats.db` filled with the fixture rows. Returns the HOME path.
function fixture.home(): string
	local made = process.exec("mktemp", { "-d" })
	assert(made.ok, made.stderr)
	local home = string.gsub(made.stdout, "%s+$", "")
	fs.writeDir(home .. "/.omp")
	local built = process.exec("sqlite3", { home .. "/.omp/stats.db", SETUP })
	assert(built.ok, built.stderr)
	return home
end

--- An empty temporary HOME, with no stats database at all.
function fixture.empty_home(): string
	local made = process.exec("mktemp", { "-d" })
	assert(made.ok, made.stderr)
	return (string.gsub(made.stdout, "%s+$", ""))
end

function fixture.remove(home: string)
	fs.removeDir(home)
end

return fixture
