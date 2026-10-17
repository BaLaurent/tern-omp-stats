--!strict
-- Number and text formatting for the dashboard. Every function accepts nil (missing SQL value) and prints "—".

local fmt = {}

local DASH = "—"

--- A number from a decoded JSON cell; nil and non-numbers are 0.
function fmt.num(x: any): number
	return if type(x) == "number" then x else 0
end

local function scaled(x: number): string
	local units = { "", "k", "M", "G", "T" }
	local i = 1
	local v = math.abs(x)
	while v >= 999.5 and i < #units do
		v /= 1000
		i += 1
	end
	local sign = if x < 0 then "-" else ""
	if i == 1 then
		return sign .. string.format("%d", math.floor(v + 0.5))
	end
	return sign .. string.format(if v >= 99.95 then "%.0f" else "%.1f", v) .. units[i]
end

--- Counts and tokens: 842, 12.3k, 4.56M.
function fmt.count(x: number?): string
	if x == nil then
		return DASH
	end
	return scaled(x)
end

--- Dollars: $0.42, $12.30, $1.2k, -$0.01 (the sign leads; a value that rounds to zero has none).
function fmt.money(x: number?): string
	if x == nil then
		return DASH
	end
	local magnitude = math.abs(x)
	local body = if magnitude >= 1000 then scaled(magnitude) else string.format("%.2f", magnitude)
	local zero = magnitude < 1000 and body == "0.00"
	return (if x < 0 and not zero then "-$" else "$") .. body
end

--- Ratio 0..1 as a percentage.
function fmt.pct(x: number?): string
	if x == nil then
		return DASH
	end
	return string.format("%.1f%%", x * 100)
end

--- Milliseconds: 420 ms, 3.4 s.
function fmt.ms(x: number?): string
	if x == nil then
		return DASH
	end
	if x < 1000 then
		return string.format("%d ms", math.floor(x + 0.5))
	end
	return string.format("%.1f s", x / 1000)
end

--- Long durations: 45 s, 12 min, 3 h 05.
function fmt.span(x: number?): string
	if x == nil then
		return DASH
	end
	local s = math.floor(x / 1000)
	if s < 60 then
		return `{s} s`
	end
	local m = math.floor(s / 60)
	if m < 60 then
		return `{m} min`
	end
	return string.format("%d h %02d", math.floor(m / 60), m % 60)
end

--- Output speed.
function fmt.rate(x: number?): string
	if x == nil then
		return DASH
	end
	return string.format("%.0f tok/s", x)
end

--- Age of a timestamp: "à l'instant", "il y a 5 min".
function fmt.ago(ms: number): string
	local s = math.max(0, math.floor(ms / 1000))
	if s < 60 then
		return "à l'instant"
	end
	local m = math.floor(s / 60)
	if m < 60 then
		return `il y a {m} min`
	end
	local h = math.floor(m / 60)
	if h < 48 then
		return `il y a {h} h`
	end
	return `il y a {math.floor(h / 24)} j`
end

--- Change between two windows as "+12%" / "-3%"; nil when there is no base to compare to.
function fmt.delta(cur: number, prev: number): (string?, number)
	if prev <= 0 then
		return nil, 0
	end
	local change = (cur - prev) / prev
	local text = string.format("%+.0f%%", change * 100)
	if text == "+0%" or text == "-0%" then
		return "±0%", 0
	end
	return text, if change > 0 then 1 else -1
end

--- omp stores a project as its mangled directory ("/run-media-…-kairon/"): drop the slashes around it.
function fmt.folder(f: any): string
	if type(f) ~= "string" or f == "" then
		return DASH
	end
	local trimmed = string.gsub(f, "^[/%-]+", "")
	trimmed = string.gsub(trimmed, "/+$", "")
	return if trimmed == "" then f else trimmed
end

--- Ratio, or nil when the denominator is zero (never divides by zero).
function fmt.ratio(a: number, b: number): number?
	if b <= 0 then
		return nil
	end
	return a / b
end

return fmt
