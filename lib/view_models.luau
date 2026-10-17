--!strict
-- Models tab: one row per model and provider, with its share of the cost.

local fmt = require("./fmt")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui

local view = {}

function view.render(d: { [string]: { any } }, _r: ranges.Range, _cols: number): Node
	local data = parts.get(d, "rows")
	local total_cost = parts.sum(data, "cost")
	local rows: { { Cell } } = {}
	for _, m in data do
		local cost = fmt.num(m.cost)
		table.insert(rows, parts.row(
			tostring(m.model),
			{ ui.span(tostring(m.provider), "muted") },
			fmt.count(fmt.num(m.req)),
			fmt.count(fmt.num(m.tot)),
			fmt.count(fmt.num(m.cr)),
			fmt.money(cost),
			parts.share(cost, total_cost),
			fmt.count(fmt.num(m.err))
		))
	end
	local cols: { Col } = {
		{ id = "model", head = "Modèle", grow = 1, priority = 5 },
		{ id = "provider", head = "Provider", priority = 1 },
		{ id = "req", head = "Req.", align = "end", priority = 4 },
		{ id = "tot", head = "Tokens", align = "end", priority = 3 },
		{ id = "cr", head = "Cache lu", align = "end", priority = 1 },
		{ id = "cost", head = "Coût", align = "end", priority = 5 },
		{ id = "share", head = "Part", priority = 2 },
		{ id = "err", head = "Err.", align = "end", priority = 2 },
	}
	return parts.panel("Modèles", { parts.table(cols, rows, "Aucune requête omp sur cette période.") })
end

return view
