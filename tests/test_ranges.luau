--!strict
local check = require("./check")
local fixture = require("./fixture")
local ranges = require("../lib/ranges")

local function r(id: string): ranges.Range
	return assert(ranges.find(id))
end

check.eq(ranges.find("nope"), nil, "unknown period is rejected")
check.eq(#ranges.list, 4, "four periods")
check.eq({ ranges.label(r("7d"), "2026-10-17"), ranges.label(r("24h"), "2026-10-17 15") }, { "10-17", "15h" }, "bucket labels")

-- The window and bucket fragments are SQL: run them against sqlite itself.
local home = fixture.home()
local db = home .. "/.omp/stats.db"
for _, range in ranges.list do
	local rows = fixture.query(
		db,
		`WITH RECURSIVE {ranges.series(range)} SELECT count(*) AS n, min(k) AS first, max(k) AS last FROM b`
	)
	check.eq(rows[1].n, range.n, `{range.id}: series has one bucket per unit`)
	local keys = fixture.query(
		db,
		`SELECT {ranges.bucket(range, ranges.since(range, 0))} AS first, {ranges.bucket(range, "CAST(strftime('%s','now') AS INTEGER)*1000")} AS last`
	)
	check.eq(keys[1].first, rows[1].first, `{range.id}: first bucket is the one holding the window start`)
	check.eq(keys[1].last, rows[1].last, `{range.id}: last bucket is the current one`)
	local span = fixture.query(db, `SELECT {ranges.since(range, 0)} - {ranges.since(range, 1)} AS d`)[1].d
	local lo, hi = range.n * (if range.unit == "hour" then 3600000 else 86400000) - 3600000, range.n * (if range.unit == "hour" then 3600000 else 86400000) + 3600000
	check.eq(span >= lo and span <= hi, true, `{range.id}: previous window is one period long (±1h for DST)`)
end
fixture.remove(home)
