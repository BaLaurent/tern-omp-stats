--!strict
-- The periods of the dashboard and the SQLite fragments that bound and bucket them.
-- Windows are calendar-aligned (local midnight / local hour) so buckets match what the user sees;
-- the previous window is the same length, immediately before the current one.

export type Range = { id: string, key: string, unit: "hour" | "day", n: number }

local ranges = {}

ranges.list = {
	{ id = "24h", key = "1", unit = "hour", n = 24 },
	{ id = "7d", key = "2", unit = "day", n = 7 },
	{ id = "30d", key = "3", unit = "day", n = 30 },
	{ id = "90d", key = "4", unit = "day", n = 90 },
} :: { Range }

function ranges.find(id: any): Range?
	for _, r in ranges.list do
		if r.id == id then
			return r
		end
	end
	return nil
end

--- Start of the current window (`back` = 0) or of the previous one (`back` = 1), as an SQL epoch-ms expression.
function ranges.since(r: Range, back: number): string
	local span = (back + 1) * r.n - 1
	if r.unit == "hour" then
		return `(CAST(strftime('%s','now') AS INTEGER)/3600*3600-{span}*3600)*1000`
	end
	return `CAST(strftime('%s','now','localtime','start of day','-{span} days','utc') AS INTEGER)*1000`
end

local function format(r: Range): string
	return if r.unit == "hour" then "%Y-%m-%d %H" else "%Y-%m-%d"
end

--- SQL expression: the local bucket key of the epoch-ms column `col`.
function ranges.bucket(r: Range, col: string): string
	return `strftime('{format(r)}',{col}/1000,'unixepoch','localtime')`
end

--- SQL common table `b(k)` listing every bucket key of the current window, oldest first.
--- Use it after `WITH RECURSIVE` so empty buckets still appear.
function ranges.series(r: Range): string
	local span = r.n - 1
	if r.unit == "hour" then
		local now = "strftime('%Y-%m-%d %H','now','localtime')"
		return `b(k) AS (SELECT strftime('%Y-%m-%d %H','now','localtime','-{span} hours') UNION ALL SELECT strftime('%Y-%m-%d %H',k||':00:00','+1 hour') FROM b WHERE k < {now})`
	end
	return `b(k) AS (SELECT date('now','localtime','-{span} days') UNION ALL SELECT date(k,'+1 day') FROM b WHERE k < date('now','localtime'))`
end

--- Short axis label of a bucket key: `"10-17"` for a day, `"15h"` for an hour.
function ranges.label(r: Range, key: string): string
	if r.unit == "hour" then
		return string.sub(key, 12, 13) .. "h"
	end
	return string.sub(key, 6)
end

return ranges
