--!strict
-- Every SQL statement of the dashboard, one builder per tab. A builder returns `{ [name]: sql }`; each
-- statement yields one JSON array. omp's rollup tables lag behind (they are only rebuilt by `omp stats`,
-- and almost every hour is marked dirty), so everything reads the raw `messages` / `tool_calls` /
-- `user_messages` tables, always bounded by the period so the timestamp indexes serve the query.
--
-- Statements are long strings with `$name` placeholders (Luau interpolation cannot span lines).

local ranges = require("./ranges")

type Range = ranges.Range
export type Queries = { [string]: string }

local queries = {}

-- A plain `GROUP BY model` makes SQLite scan a whole-history index (idx_messages_model, idx_messages_folder,
-- idx_tool_calls_tool_timestamp…) instead of range-searching the timestamp index, so the cost would grow
-- with the age of the database rather than with the period. The unary `+` on a group key rules those indexes
-- out and keeps the plan a `SEARCH … (timestamp>?)`. tests/test_queries.luau pins this with EXPLAIN QUERY PLAN.

local ROW_LIMIT = 60

local function sql(template: string, vars: { [string]: string | number }): string
	local out = string.gsub(template, "%$(%w+)", function(name: string): string
		local value = vars[name]
		if value == nil then
			error("unbound SQL placeholder $" .. name)
		end
		return tostring(value)
	end)
	return out
end

--- Newest request time and the database clock, so the footer can say how fresh the data is.
local META = "SELECT max(timestamp) AS last_ts, CAST(strftime('%s','now') AS INTEGER)*1000 AS now FROM messages"

--- Bounds shared by every builder: `$s0` current window start, `$s1` previous window start,
--- `$w` the 0 (current) / 1 (previous) window of a row, `$limit`.
local function bounds(r: Range): { [string]: string | number }
	local s0, s1 = ranges.since(r, 0), ranges.since(r, 1)
	return {
		s0 = s0,
		s1 = s1,
		w = `CASE WHEN timestamp >= {s0} THEN 0 ELSE 1 END`,
		limit = ROW_LIMIT,
		series = ranges.series(r),
		bucket = ranges.bucket(r, "timestamp"),
	}
end

function queries.overview(r: Range): Queries
	local v = bounds(r)
	return {
		meta = META,
		kpi = sql(
			[[SELECT $w AS w, count(*) AS req, total(cost_total) AS cost, total(input_tokens) AS inp,
				total(output_tokens) AS outp, total(cache_read_tokens) AS cr, total(cache_write_tokens) AS cw,
				total(total_tokens) AS tot, total(stop_reason = 'error') AS err, total(cost_unpriced > 0) AS unpriced,
				total(cost_no_cache_input) AS nc, total(cost_input + cost_cache_read + cost_cache_write) AS cc
				FROM messages WHERE timestamp >= $s1 GROUP BY w]],
			v
		),
		prompts = sql([[SELECT $w AS w, count(*) AS n FROM user_messages WHERE timestamp >= $s1 GROUP BY w]], v),
		series = sql(
			[[WITH RECURSIVE $series,
				a AS (SELECT $bucket AS k, total(cost_total) AS cost, count(*) AS req
					FROM messages WHERE timestamp >= $s0 GROUP BY k)
				SELECT b.k AS k, coalesce(a.cost, 0) AS cost, coalesce(a.req, 0) AS req
				FROM b LEFT JOIN a ON a.k = b.k ORDER BY b.k]],
			v
		),
	}
end

function queries.models(r: Range): Queries
	return {
		meta = META,
		rows = sql(
			[[SELECT model, provider, count(*) AS req, total(cost_total) AS cost, total(total_tokens) AS tot,
				total(input_tokens) AS inp, total(output_tokens) AS outp, total(cache_read_tokens) AS cr,
				total(stop_reason = 'error') AS err
				FROM messages WHERE timestamp >= $s0
				GROUP BY +model, +provider ORDER BY cost DESC LIMIT $limit]],
			bounds(r)
		),
	}
end

function queries.projects(r: Range): Queries
	local v = bounds(r)
	return {
		meta = META,
		rows = sql(
			[[SELECT folder, count(*) AS req, total(cost_total) AS cost, total(total_tokens) AS tot,
				total(stop_reason = 'error') AS err, max(timestamp) AS last_ts
				FROM messages WHERE timestamp >= $s0 GROUP BY +folder ORDER BY cost DESC LIMIT $limit]],
			v
		),
		agents = sql(
			[[SELECT agent_type, count(*) AS req, total(cost_total) AS cost, total(total_tokens) AS tot
				FROM messages WHERE timestamp >= $s0 GROUP BY agent_type ORDER BY cost DESC]],
			v
		),
	}
end

-- Output speed counts only requests that produced tokens over a measured duration.
local PERFORMANCE_AGGREGATES = [[count(*) AS req, avg(ttft) AS ttft, avg(duration) AS dur,
	total(CASE WHEN output_tokens > 0 AND duration > 0 THEN output_tokens END) AS tps_out,
	total(CASE WHEN output_tokens > 0 AND duration > 0 THEN duration END) AS tps_ms,
	total(cache_read_tokens) AS cr, total(input_tokens) AS inp, total(cache_write_tokens) AS cw,
	total(cost_no_cache_input) AS nc, total(cost_input + cost_cache_read + cost_cache_write) AS cc]]

function queries.performance(r: Range): Queries
	local v = bounds(r)
	v.agg = PERFORMANCE_AGGREGATES
	return {
		meta = META,
		total = sql([[SELECT $agg FROM messages WHERE timestamp >= $s0]], v),
		rows = sql(
			[[SELECT model, provider, $agg FROM messages WHERE timestamp >= $s0
				GROUP BY +model, +provider ORDER BY req DESC LIMIT $limit]],
			v
		),
		series = sql(
			[[WITH RECURSIVE $series,
				a AS (SELECT $bucket AS k, avg(ttft) AS ttft FROM messages WHERE timestamp >= $s0 GROUP BY k)
				SELECT b.k AS k, coalesce(a.ttft, 0) AS ttft FROM b LEFT JOIN a ON a.k = b.k ORDER BY b.k]],
			v
		),
	}
end

function queries.tools(r: Range): Queries
	local v = bounds(r)
	return {
		meta = META,
		total = sql(
			[[SELECT count(*) AS calls, total(is_error) AS err, count(DISTINCT tool_name) AS kinds
				FROM tool_calls WHERE timestamp >= $s0]],
			v
		),
		rows = sql(
			[[SELECT tool_name, count(*) AS calls, total(is_error) AS err, avg(args_chars) AS args,
				avg(result_chars) AS res
				FROM tool_calls WHERE timestamp >= $s0 GROUP BY +tool_name ORDER BY calls DESC LIMIT $limit]],
			v
		),
	}
end

function queries.sessions(r: Range): Queries
	return {
		meta = META,
		rows = sql(
			[[SELECT session_file, min(folder) AS folder, min(timestamp) AS t0, max(timestamp) AS t1,
				strftime('%m-%d %H:%M', min(timestamp)/1000, 'unixepoch', 'localtime') AS started,
				count(*) AS req, total(cost_total) AS cost, total(total_tokens) AS tot,
				group_concat(DISTINCT model) AS models
				FROM messages WHERE timestamp >= $s0
				GROUP BY +session_file ORDER BY t1 DESC LIMIT $limit]],
			bounds(r)
		),
	}
end

return queries
