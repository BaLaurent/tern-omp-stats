--!strict
-- Overview tab: headline KPIs with the change against the previous window, cost and request trends, token mix.

local fmt = require("./fmt")
local i18n = require("./i18n")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui
local t = i18n.t

local view = {}

function view.render(d: { [string]: { any } }, r: ranges.Range, _cols: number): Node
	local cur, prev = parts.window(d.kpi, 0), parts.window(d.kpi, 1)
	local req = fmt.num(cur.req)
	if req == 0 then
		return parts.empty(t("empty_requests"))
	end
	local cost, prev_cost = fmt.num(cur.cost), fmt.num(prev.cost)
	local tot = fmt.num(cur.tot)
	local err_rate = fmt.ratio(fmt.num(cur.err), req)
	local prev_rate = fmt.ratio(fmt.num(prev.err), fmt.num(prev.req)) or 0
	local hit = parts.cache_hit(fmt.num(cur.cr), fmt.num(cur.inp), fmt.num(cur.cw))
	local saved = fmt.num(cur.nc) - fmt.num(cur.cc)
	local prompts, prev_prompts = fmt.num(parts.window(d.prompts, 0).n), fmt.num(parts.window(d.prompts, 1).n)

	local tiles = {
		parts.kpi(t("kpi_cost"), fmt.money(cost), parts.delta(cost, prev_cost)),
		parts.kpi(t("kpi_requests"), fmt.count(req), parts.delta(req, fmt.num(prev.req))),
		parts.kpi(
			t("kpi_tokens"),
			fmt.count(tot),
			{ fmt.count(fmt.num(cur.inp)) .. " in · " .. fmt.count(fmt.num(cur.outp)) .. " out" }
		),
		parts.kpi(t("kpi_prompts"), fmt.count(prompts), parts.delta(prompts, prev_prompts)),
		parts.kpi(
			t("kpi_error_rate"),
			fmt.pct(err_rate),
			parts.delta(err_rate or 0, prev_rate, true) or { i18n.tf("errors_count", fmt.count(fmt.num(cur.err))) }
		),
		parts.kpi(t("kpi_cache"), fmt.pct(hit), { i18n.tf("saved", fmt.money(saved)) }),
	}

	local body: { Node } = { parts.kpis(tiles) }
	local unpriced = fmt.num(cur.unpriced)
	if unpriced > 0 then
		table.insert(
			body,
			ui.row({
				ui.badge(i18n.tf("unpriced", fmt.count(unpriced)), "warn"),
				ui.text({ ui.span(t("unpriced_note"), "muted") }),
			})
		)
	end

	local series = parts.get(d, "series")
	local per = parts.per(r)
	table.insert(
		body,
		parts.grid({
			parts.panel(i18n.tf("cost_per", per), { parts.trend(r, series, "cost", fmt.money) }),
			parts.panel(i18n.tf("requests_per", per), { parts.trend(r, series, "req", fmt.count) }),
		})
	)

	local mix: { { label: string, tokens: number } } = {
		{ label = t("mix_input"), tokens = fmt.num(cur.inp) },
		{ label = t("mix_output"), tokens = fmt.num(cur.outp) },
		{ label = t("mix_cache_read"), tokens = fmt.num(cur.cr) },
		{ label = t("mix_cache_write"), tokens = fmt.num(cur.cw) },
	}
	local mix_total = 0
	for _, kind in mix do
		mix_total += kind.tokens
	end
	local mix_rows: { { Cell } } = {}
	for _, kind in mix do
		table.insert(mix_rows, parts.row(kind.label, fmt.count(kind.tokens), parts.share(kind.tokens, mix_total)))
	end
	local mix_cols: { Col } = {
		{ id = "kind", head = t("col_type"), grow = 1, priority = 3 },
		{ id = "tokens", head = t("col_tokens"), align = "end", priority = 3 },
		{ id = "share", head = t("col_share"), priority = 2 },
	}
	table.insert(body, parts.panel(t("kpi_tokens"), { ui.table(mix_cols, mix_rows) }))
	return ui.col(body)
end

return view
