--!strict
-- Tools tab: call volume and failure rate per tool.

local fmt = require("./fmt")
local i18n = require("./i18n")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui
local t = i18n.t

local view = {}

local FAILURE_THRESHOLDS = { 0.1, 0.25 }

function view.render(d: { [string]: { any } }, _r: ranges.Range, _cols: number): Node
	local all = parts.first(d, "total")
	local calls = fmt.num(all.calls)
	if calls == 0 then
		return parts.empty(t("empty_tools"))
	end
	local tiles = {
		parts.kpi(t("kpi_calls"), fmt.count(calls)),
		parts.kpi(
			t("kpi_failure_rate"),
			fmt.pct(fmt.ratio(fmt.num(all.err), calls)),
			{ i18n.tf("failures_count", fmt.count(fmt.num(all.err))) }
		),
		parts.kpi(t("kpi_distinct"), fmt.count(fmt.num(all.kinds))),
	}

	local data = parts.get(d, "rows")
	local rows: { { Cell } } = {}
	for _, tool in data do
		local n = fmt.num(tool.calls)
		table.insert(rows, parts.row(
			tostring(tool.tool_name),
			fmt.count(n),
			parts.share(n, calls),
			fmt.count(fmt.num(tool.err)),
			ui.meter_cell(fmt.ratio(fmt.num(tool.err), n) or 0, FAILURE_THRESHOLDS),
			fmt.count(tool.args),
			fmt.count(tool.res)
		))
	end
	local cols: { Col } = {
		{ id = "tool", head = t("col_tool"), grow = 1, priority = 5 },
		{ id = "calls", head = t("col_calls"), align = "end", priority = 5 },
		{ id = "share", head = t("col_share"), priority = 3 },
		{ id = "err", head = t("col_failures"), align = "end", priority = 3 },
		{ id = "rate", head = t("col_failure_rate"), priority = 4 },
		{ id = "args", head = t("col_args"), align = "end", priority = 1 },
		{ id = "res", head = t("col_result"), align = "end", priority = 1 },
	}
	return ui.col({
		parts.kpis(tiles),
		parts.panel(t("panel_tools"), { parts.table(cols, rows, t("empty_tools")) }),
	})
end

return view
