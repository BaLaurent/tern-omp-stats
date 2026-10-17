--!strict
-- Projects tab: cost per project directory, and per agent type (main / subagent / advisor).

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
	local clock = parts.first(d, "meta")
	local now = if clock then fmt.num(clock.now) else 0
	local rows: { { Cell } } = {}
	for _, p in data do
		local cost = fmt.num(p.cost)
		local last = if now > 0 and p.last_ts then parts.ago(now - fmt.num(p.last_ts)) else parts.ago(0)
		table.insert(rows, parts.row(
			fmt.folder(p.folder),
			fmt.count(fmt.num(p.req)),
			fmt.count(fmt.num(p.tot)),
			fmt.money(cost),
			parts.share(cost, total_cost),
			fmt.count(fmt.num(p.err)),
			{ ui.span(last, "muted") }
		))
	end
	local cols: { Col } = {
		{ id = "folder", head = t("col_project"), grow = 1, priority = 5, truncate = "start" },
		{ id = "req", head = t("col_req"), align = "end", priority = 4 },
		{ id = "tot", head = t("col_tokens"), align = "end", priority = 2 },
		{ id = "cost", head = t("col_cost"), align = "end", priority = 5 },
		{ id = "share", head = t("col_share"), priority = 3 },
		{ id = "err", head = t("col_err"), align = "end", priority = 1 },
		{ id = "last", head = t("col_last"), priority = 1 },
	}

	local agents: { any } = d.agents or {}
	local agent_total = parts.sum(agents, "cost")
	local agent_rows: { { Cell } } = {}
	for _, a in agents do
		local cost = fmt.num(a.cost)
		table.insert(agent_rows, parts.row(
			tostring(a.agent_type),
			fmt.count(fmt.num(a.req)),
			fmt.count(fmt.num(a.tot)),
			fmt.money(cost),
			parts.share(cost, agent_total)
		))
	end
	local agent_cols: { Col } = {
		{ id = "agent", head = t("col_agent"), grow = 1, priority = 5 },
		{ id = "req", head = t("col_req"), align = "end", priority = 4 },
		{ id = "tot", head = t("col_tokens"), align = "end", priority = 2 },
		{ id = "cost", head = t("col_cost"), align = "end", priority = 5 },
		{ id = "share", head = t("col_share"), priority = 3 },
	}
	return ui.col({
		parts.panel(t("panel_projects"), { parts.table(cols, rows, t("empty_requests")) }),
		parts.panel(t("panel_agents"), { parts.table(agent_cols, agent_rows, t("empty_requests")) }),
	})
end

return view
