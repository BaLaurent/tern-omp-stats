--!strict
-- The dashboard's SQL against the fixture database (see fixture.luau for the rows).
local check = require("./check")
local fixture = require("./fixture")
local queries = require("../lib/queries")
local ranges = require("../lib/ranges")

local home = fixture.home()
local db = home .. "/.omp/stats.db"

local function run(builder: (ranges.Range) -> queries.Queries, id: string): { [string]: { any } }
	local out: { [string]: { any } } = {}
	for name, sql in builder(assert(ranges.find(id))) do
		out[name] = fixture.query(db, sql)
	end
	return out
end

local function by_window(rows: { any }, w: number): any
	for _, row in rows do
		if row.w == w then
			return row
		end
	end
	return {}
end

local function sum(rows: { any }, field: string): number
	local total = 0
	for _, row in rows do
		total += row[field]
	end
	return total
end

-- Overview, 24 h: A and B now, C in the previous window, D out of both.
local o24 = run(queries.overview, "24h")
local cur, prev = by_window(o24.kpi, 0), by_window(o24.kpi, 1)
check.eq({ cur.req, cur.err, cur.inp, cur.outp, cur.cr, cur.cw }, { 2, 1, 110, 50, 1000, 10 }, "24h current counts")
check.near(cur.cost, 3.0, "24h current cost")
check.near(cur.nc - cur.cc, 5.5 - 0.6, "24h cache saving = no-cache prompt cost - actual prompt cost")
check.eq({ prev.req, prev.cost }, { 1, 4.0 }, "24h previous window holds C only")
check.eq({ by_window(o24.prompts, 0).n, by_window(o24.prompts, 1).n }, { 2, 1 }, "24h prompts per window")
check.eq(#o24.series, 24, "24h series has 24 hourly buckets, empty ones included")
check.near(sum(o24.series, "cost"), 3.0, "24h series adds up to the window cost")
check.eq(o24.meta[1].now - o24.meta[1].last_ts < 4 * 3600000, true, "meta: newest request age")

-- Overview, 7 d: C joins the current window, D is the previous one.
local o7 = run(queries.overview, "7d")
check.eq(by_window(o7.kpi, 0).req, 3, "7d current requests")
check.near(by_window(o7.kpi, 0).cost, 7.0, "7d current cost")
check.near(by_window(o7.kpi, 1).cost, 8.0, "7d previous cost is D")
check.eq(by_window(o7.kpi, 1).unpriced, 1, "unpriced requests are counted")
check.eq(#o7.series, 7, "7d series has 7 daily buckets")
check.near(sum(o7.series, "cost"), 7.0, "7d series adds up")

local o30 = run(queries.overview, "30d")
check.eq({ #o30.series, by_window(o30.kpi, 0).req }, { 30, 4 }, "30d covers D")
check.near(sum(o30.series, "cost"), 15.0, "30d series adds up")

-- Models: ordered by cost.
local m = run(queries.models, "7d").rows
check.eq({ m[1].model, m[2].model }, { "m1", "m2" }, "models ordered by cost")
check.near(m[1].cost, 5.0, "m1 cost over 7d")
check.eq({ m[1].req, m[2].err }, { 2, 1 }, "model request and error counts")

-- Projects and agent types.
local p = run(queries.projects, "7d")
check.eq({ p.rows[1].folder, p.rows[2].folder }, { "/proj-a/", "/proj-b/" }, "projects ordered by cost")
check.eq({ p.agents[1].agent_type, p.agents[2].agent_type }, { "main", "subagent" }, "agent types ordered by cost")

-- Performance: speed only counts requests with output and a measured duration.
local perf = run(queries.performance, "24h")
local total = perf.total[1]
check.eq({ total.req, total.ttft, total.tps_out, total.tps_ms }, { 2, 500, 50, 2000 }, "24h performance totals")
check.eq(#perf.series, 24, "ttft series per hour")
check.eq(#perf.rows, 2, "performance per model")

-- Tools.
local tools = run(queries.tools, "7d")
check.eq({ tools.total[1].calls, tools.total[1].err, tools.total[1].kinds }, { 4, 1, 2 }, "7d tool totals")
check.eq({ tools.rows[1].tool_name, tools.rows[1].calls, tools.rows[1].err }, { "bash", 3, 1 }, "bash is the top tool")
check.eq(run(queries.tools, "30d").total[1].calls, 5, "30d includes the old bash call")

-- Sessions: newest activity first.
local s = run(queries.sessions, "7d").rows
check.eq({ s[1].session_file, s[2].session_file, s[3].session_file }, { "s1", "s2", "s3" }, "sessions ordered by last request")
check.eq({ s[1].req, s[1].models }, { 1, "m1" }, "session counts and models")

-- Plans: every statement range-searches the timestamp index. A SCAN of omp's tables would make the cost
-- grow with the age of the database (and read the whole file on a cold cache) instead of the period.
-- (`SCAN b` walks the generated bucket list and `SCAN CONSTANT ROW` is a literal: both are tiny.)
for tab, builder in queries :: any do
	for _, range in ranges.list do
		for name, sql in builder(range) do
			for target in string.gmatch(fixture.plan(db, sql), "SCAN ([%w_]+)") do
				check.eq(target == "b" or target == "CONSTANT", true, `{tab}.{name} ({range.id}) scans {target}`)
			end
		end
	end
end

-- Empty period: aggregates are 0 rows or zeros, never errors.
fixture.exec(db, "DELETE FROM messages; DELETE FROM tool_calls; DELETE FROM user_messages;")
local empty = run(queries.overview, "7d")
check.eq(#empty.kpi, 0, "no requests: no kpi rows")
check.eq(#empty.series, 7, "no requests: the series still lists every day")
check.eq(#run(queries.tools, "7d").rows, 0, "no tool calls: no rows")

fixture.remove(home)
