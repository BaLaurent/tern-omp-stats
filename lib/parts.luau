--!strict
-- Building blocks shared by the tab views: KPI tiles, panels, tables and charts on top of `tern.ui`.

local fmt = require("./fmt")
local ranges = require("./ranges")

local ui = tern.ui

local parts = {}

--- The rows of statement `name`, empty when it is missing.
function parts.get(d: { [string]: { any } }, name: string): { any }
	local rows: { any } = d[name] or {}
	return rows
end

--- The first row of statement `name`, empty when there is none.
function parts.first(d: { [string]: { any } }, name: string): { [string]: any }
	local row: { [string]: any } = parts.get(d, name)[1] or {}
	return row
end

--- The rows of a statement where column `w` is `which` (0 = current window, 1 = previous).
function parts.window(rows: { any }?, which: number): { [string]: any }
	local list: { any } = rows or {}
	for _, row in list do
		if fmt.num(row.w) == which then
			return row
		end
	end
	return {}
end

--- A change against the previous window, as a span. `bad_up`: an increase is bad news (errors).
function parts.delta(cur: number, prev: number, bad_up: boolean?): Span?
	local text, dir = fmt.delta(cur, prev)
	if not text then
		return nil
	end
	local tone = "muted"
	if dir ~= 0 and bad_up then
		tone = if dir > 0 then "error" else "success"
	end
	return ui.span(text .. " vs période préc.", tone)
end

--- A tile: label, big value, optional detail spans.
function parts.kpi(label: string, value: string, detail: Spans?): Node
	local children: { Node } = {
		ui.el("div", { class = "os-kpi-label", text = label }),
		ui.el("div", { class = "os-kpi-value", text = value }),
	}
	if detail then
		table.insert(children, ui.el("div", { class = "os-kpi-detail" }, { ui.text(detail) }))
	end
	return ui.el("div", { class = "os-kpi" }, children)
end

--- Tiles that wrap to the pane width.
function parts.kpis(tiles: { Node }): Node
	return ui.el("div", { class = "os-kpis" }, tiles)
end

--- Panels that sit side by side when the pane is wide and stack when it is not.
function parts.grid(panels: { Node }): Node
	return ui.el("div", { class = "os-grid" }, panels)
end

function parts.panel(title: string, children: { Node }): Node
	return ui.el("div", { class = "os-panel" }, { ui.card(title, children) })
end

function parts.empty(message: string): Node
	return ui.text({ ui.span(message, "muted") })
end

--- `{label, value}` pairs for a bars chart from the rows of a bucketed statement.
function parts.pairs(r: ranges.Range, rows: { any }, field: string): { { any } }
	local out: { { any } } = {}
	for _, row in rows do
		local pair: { any } = { ranges.label(r, tostring(row.k)), fmt.num(row[field]) }
		table.insert(out, pair)
	end
	return out
end

--- A bar chart over time with a caption: the chart's own labels are hover tooltips only (the native `spark` is a
--- 19 px miniature), so the caption gives the first and last bucket and the peak. `show` formats a value.
function parts.trend(r: ranges.Range, rows: { any }, field: string, show: (number) -> string): Node
	local series = parts.pairs(r, rows, field)
	local peak_at, peak = 0, 0
	for i, pair in series do
		local value = pair[2] :: number
		if value > peak then
			peak_at, peak = i, value
		end
	end
	local caption = "aucune donnée sur la période"
	if peak_at > 0 then
		caption = `{series[1][1]} → {series[#series][1]}  ·  pic {show(peak)} ({series[peak_at][1]})`
	end
	return ui.col({ ui.bars(series), ui.text({ ui.span(caption, "muted") }) })
end

--- A table row from its cells (a literal of mixed strings, spans and meters does not infer as `{ Cell }`).
function parts.row(...: Cell): { Cell }
	return { ... }
end

--- Share of `part` in `whole`, as a table meter cell.
function parts.share(part: number, whole: number): Cell
	return ui.meter_cell(if whole > 0 then math.min(1, part / whole) else 0)
end

--- A table, or `empty_message` when there are no rows.
function parts.table(cols: { Col }, rows: { { Cell } }, empty_message: string): Node
	if #rows == 0 then
		return parts.empty(empty_message)
	end
	return ui.table(cols, rows)
end

--- Sum of a numeric field over rows.
function parts.sum(rows: { any }, field: string): number
	local total = 0
	for _, row in rows do
		total += fmt.num(row[field])
	end
	return total
end

--- Share of cached prompt tokens among all prompt tokens.
function parts.cache_hit(cr: number, inp: number, cw: number): number?
	return fmt.ratio(cr, inp + cr + cw)
end

return parts
