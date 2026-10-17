--!strict
-- Sessions tab: the most recently active sessions of the period.

local fmt = require("./fmt")
local i18n = require("./i18n")
local parts = require("./parts")
local ranges = require("./ranges")

local t = i18n.t

local view = {}

function view.render(d: { [string]: { any } }, _r: ranges.Range, _cols: number): Node
	local rows: { { Cell } } = {}
	local sessions = parts.get(d, "rows")
	for _, s in sessions do
		table.insert(rows, parts.row(
			tostring(s.started),
			fmt.folder(s.folder),
			fmt.span(fmt.num(s.t1) - fmt.num(s.t0)),
			fmt.count(fmt.num(s.req)),
			fmt.count(fmt.num(s.tot)),
			fmt.money(fmt.num(s.cost)),
			tostring(s.models or "")
		))
	end
	local cols: { Col } = {
		{ id = "started", head = t("col_start"), priority = 5 },
		{ id = "folder", head = t("col_project"), grow = 1, priority = 4, truncate = "start" },
		{ id = "span", head = t("col_duration"), align = "end", priority = 3 },
		{ id = "req", head = t("col_req"), align = "end", priority = 4 },
		{ id = "tot", head = t("col_tokens"), align = "end", priority = 2 },
		{ id = "cost", head = t("col_cost"), align = "end", priority = 5 },
		{ id = "models", head = t("panel_models"), priority = 1, truncate = "end" },
	}
	return parts.panel(t("panel_sessions"), { parts.table(cols, rows, t("empty_sessions")) })
end

return view
