--!strict
-- Overview tab: headline KPIs with the change against the previous window, cost and request trends, token mix.

local fmt = require("./fmt")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui

local view = {}

function view.render(d: { [string]: { any } }, r: ranges.Range, _cols: number): Node
	local cur, prev = parts.window(d.kpi, 0), parts.window(d.kpi, 1)
	local req = fmt.num(cur.req)
	if req == 0 then
		return parts.empty("Aucune requête omp sur cette période.")
	end
	local cost, prev_cost = fmt.num(cur.cost), fmt.num(prev.cost)
	local tot = fmt.num(cur.tot)
	local err_rate = fmt.ratio(fmt.num(cur.err), req)
	local prev_rate = fmt.ratio(fmt.num(prev.err), fmt.num(prev.req)) or 0
	local hit = parts.cache_hit(fmt.num(cur.cr), fmt.num(cur.inp), fmt.num(cur.cw))
	local saved = fmt.num(cur.nc) - fmt.num(cur.cc)
	local prompts, prev_prompts = fmt.num(parts.window(d.prompts, 0).n), fmt.num(parts.window(d.prompts, 1).n)

	local tiles = {
		parts.kpi("Coût", fmt.money(cost), parts.delta(cost, prev_cost)),
		parts.kpi("Requêtes", fmt.count(req), parts.delta(req, fmt.num(prev.req))),
		parts.kpi(
			"Tokens",
			fmt.count(tot),
			{ fmt.count(fmt.num(cur.inp)) .. " in · " .. fmt.count(fmt.num(cur.outp)) .. " out" }
		),
		parts.kpi("Prompts", fmt.count(prompts), parts.delta(prompts, prev_prompts)),
		parts.kpi(
			"Taux d'erreur",
			fmt.pct(err_rate),
			parts.delta(err_rate or 0, prev_rate, true) or { fmt.count(fmt.num(cur.err)) .. " erreurs" }
		),
		parts.kpi("Cache", fmt.pct(hit), { "économie " .. fmt.money(saved) }),
	}

	local body: { Node } = { parts.kpis(tiles) }
	local unpriced = fmt.num(cur.unpriced)
	if unpriced > 0 then
		table.insert(body, ui.row({ ui.badge(`{fmt.count(unpriced)} requêtes sans prix`, "warn"), ui.text({ ui.span("exclues du coût", "muted") }) }))
	end

	local series = parts.get(d, "series")
	local trend_head = if r.unit == "hour" then "par heure" else "par jour"
	table.insert(
		body,
		parts.grid({
			parts.panel(`Coût {trend_head}`, { parts.trend(r, series, "cost", fmt.money) }),
			parts.panel(`Requêtes {trend_head}`, { parts.trend(r, series, "req", fmt.count) }),
		})
	)

	local mix: { { label: string, tokens: number } } = {
		{ label = "Entrée", tokens = fmt.num(cur.inp) },
		{ label = "Sortie", tokens = fmt.num(cur.outp) },
		{ label = "Cache lu", tokens = fmt.num(cur.cr) },
		{ label = "Cache écrit", tokens = fmt.num(cur.cw) },
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
		{ id = "kind", head = "Type", grow = 1, priority = 3 },
		{ id = "tokens", head = "Tokens", align = "end", priority = 3 },
		{ id = "share", head = "Part", priority = 2 },
	}
	table.insert(body, parts.panel("Tokens", { ui.table(mix_cols, mix_rows) }))
	return ui.col(body)
end

return view
