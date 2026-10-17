--!strict
-- Models tab: one row per model and provider, with its share of the cost.

local fmt = require("./fmt")
local i18n = require("./i18n")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui
local t = i18n.t

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
		{ id = "model", head = t("col_model"), grow = 1, priority = 5 },
		{ id = "provider", head = t("col_provider"), priority = 1 },
		{ id = "req", head = t("col_req"), align = "end", priority = 4 },
		{ id = "tot", head = t("col_tokens"), align = "end", priority = 3 },
		{ id = "cr", head = t("col_cache_read"), align = "end", priority = 1 },
		{ id = "cost", head = t("col_cost"), align = "end", priority = 5 },
		{ id = "share", head = t("col_share"), priority = 2 },
		{ id = "err", head = t("col_err"), align = "end", priority = 2 },
	}
	return parts.panel(t("panel_models"), { parts.table(cols, rows, t("empty_requests")) })
end

return view
