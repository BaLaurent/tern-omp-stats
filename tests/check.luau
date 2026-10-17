--!strict
local check = { count = 0 }

local function same(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function show(v: any): string
	if type(v) ~= "table" then
		return if type(v) == "string" then string.format("%q", v) else tostring(v)
	end
	local parts: { string } = {}
	for k, x in v do
		table.insert(parts, tostring(k) .. "=" .. show(x))
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

function check.eq(actual: any, expected: any, label: string)
	check.count += 1
	if not same(actual, expected) then
		error(`FAIL {label}\n  expected {show(expected)}\n  actual   {show(actual)}`, 2)
	end
end

function check.near(actual: any, expected: number, label: string)
	check.count += 1
	if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
		error(`FAIL {label}\n  expected ~{expected}\n  actual   {show(actual)}`, 2)
	end
end

--- `text` contains `needle` (plain).
function check.has(text: string, needle: string, label: string)
	check.count += 1
	if not string.find(text, needle, 1, true) then
		error(`FAIL {label}\n  missing {show(needle)} in\n  {text}`, 2)
	end
end

function check.lacks(text: string, needle: string, label: string)
	check.count += 1
	if string.find(text, needle, 1, true) then
		error(`FAIL {label}\n  unexpected {show(needle)} in\n  {text}`, 2)
	end
end

return check
