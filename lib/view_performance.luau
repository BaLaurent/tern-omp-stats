--!strict
-- Performance tab: latency, output speed and prompt-cache efficiency, overall and per model.

local fmt = require("./fmt")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui

local view = {}

--- Output tokens per second over the requests that were measured; nil when none were.
local function speed(row: { [string]: any }): number?
	local ms = fmt.num(row.tps_ms)
	if ms <= 0 then
		return nil
	end
	return fmt.num(row.tps_out) / (ms / 1000)
end

local function avg(x: any): number?
	return if type(x) == "number" then x else nil
end

function view.render(d: { [string]: { any } }, r: ranges.Range, _cols: number): Node
	local all = parts.first(d, "total")
	local req = fmt.num(all.req)
	if req == 0 then
		return parts.empty("Aucune requête omp sur cette période.")
	end
	local hit = parts.cache_hit(fmt.num(all.cr), fmt.num(all.inp), fmt.num(all.cw))
	local saved = fmt.num(all.nc) - fmt.num(all.cc)
	local tiles = {
		parts.kpi("TTFT moyen", fmt.ms(avg(all.ttft)), { "délai avant le 1er token" }),
		parts.kpi("Durée moyenne", fmt.ms(avg(all.dur))),
		parts.kpi("Débit", fmt.rate(speed(all)), { "tokens de sortie / s" }),
		parts.kpi("Cache hit", fmt.pct(hit)),
		parts.kpi("Économie du cache", fmt.money(saved), { "vs prompt sans cache" }),
		parts.kpi("Requêtes", fmt.count(req)),
	}

	local rows: { { Cell } } = {}
	local models = parts.get(d, "rows")
	for _, m in models do
		local m_hit = parts.cache_hit(fmt.num(m.cr), fmt.num(m.inp), fmt.num(m.cw))
		table.insert(rows, parts.row(
			tostring(m.model),
			fmt.count(fmt.num(m.req)),
			fmt.ms(avg(m.ttft)),
			fmt.ms(avg(m.dur)),
			fmt.rate(speed(m)),
			ui.meter_cell(m_hit or 0),
			fmt.money(fmt.num(m.nc) - fmt.num(m.cc))
		))
	end
	local cols: { Col } = {
		{ id = "model", head = "Modèle", grow = 1, priority = 5 },
		{ id = "req", head = "Req.", align = "end", priority = 4 },
		{ id = "ttft", head = "TTFT", align = "end", priority = 5 },
		{ id = "dur", head = "Durée", align = "end", priority = 3 },
		{ id = "tps", head = "Débit", align = "end", priority = 4 },
		{ id = "hit", head = "Cache hit", priority = 2 },
		{ id = "saved", head = "Économie", align = "end", priority = 1 },
	}
	local trend_head = if r.unit == "hour" then "par heure" else "par jour"
	return ui.col({
		parts.kpis(tiles),
		parts.panel(`TTFT moyen {trend_head}`, { parts.trend(r, parts.get(d, "series"), "ttft", fmt.ms) }),
		parts.panel("Par modèle", { parts.table(cols, rows, "Aucune requête omp sur cette période.") }),
	})
end

return view
