--!strict
-- Tools tab: call volume and failure rate per tool.

local fmt = require("./fmt")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui

local view = {}

local FAILURE_THRESHOLDS = { 0.1, 0.25 }

function view.render(d: { [string]: { any } }, _r: ranges.Range, _cols: number): Node
	local all = parts.first(d, "total")
	local calls = fmt.num(all.calls)
	if calls == 0 then
		return parts.empty("Aucun appel d'outil sur cette période.")
	end
	local tiles = {
		parts.kpi("Appels", fmt.count(calls)),
		parts.kpi("Taux d'échec", fmt.pct(fmt.ratio(fmt.num(all.err), calls)), { fmt.count(fmt.num(all.err)) .. " échecs" }),
		parts.kpi("Outils distincts", fmt.count(fmt.num(all.kinds))),
	}

	local data = parts.get(d, "rows")
	local rows: { { Cell } } = {}
	for _, t in data do
		local n = fmt.num(t.calls)
		table.insert(rows, parts.row(
			tostring(t.tool_name),
			fmt.count(n),
			parts.share(n, calls),
			fmt.count(fmt.num(t.err)),
			ui.meter_cell(fmt.ratio(fmt.num(t.err), n) or 0, FAILURE_THRESHOLDS),
			fmt.count(t.args),
			fmt.count(t.res)
		))
	end
	local cols: { Col } = {
		{ id = "tool", head = "Outil", grow = 1, priority = 5 },
		{ id = "calls", head = "Appels", align = "end", priority = 5 },
		{ id = "share", head = "Part", priority = 3 },
		{ id = "err", head = "Échecs", align = "end", priority = 3 },
		{ id = "rate", head = "Taux d'échec", priority = 4 },
		{ id = "args", head = "Args moy.", align = "end", priority = 1 },
		{ id = "res", head = "Résultat moy.", align = "end", priority = 1 },
	}
	return ui.col({
		parts.kpis(tiles),
		parts.panel("Outils", { parts.table(cols, rows, "Aucun appel d'outil sur cette période.") }),
	})
end

return view
