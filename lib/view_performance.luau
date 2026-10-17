--!strict
-- Performance tab: latency, output speed and prompt-cache efficiency, overall and per model.

local fmt = require("./fmt")
local i18n = require("./i18n")
local parts = require("./parts")
local ranges = require("./ranges")

local ui = tern.ui
local t = i18n.t

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
		return parts.empty(t("empty_requests"))
	end
	local hit = parts.cache_hit(fmt.num(all.cr), fmt.num(all.inp), fmt.num(all.cw))
	local saved = fmt.num(all.nc) - fmt.num(all.cc)
	local tiles = {
		parts.kpi(t("kpi_ttft"), fmt.ms(avg(all.ttft)), { t("kpi_ttft_detail") }),
		parts.kpi(t("kpi_duration"), fmt.ms(avg(all.dur))),
		parts.kpi(t("kpi_speed"), fmt.rate(speed(all)), { t("kpi_speed_detail") }),
		parts.kpi(t("kpi_cache_hit"), fmt.pct(hit)),
		parts.kpi(t("kpi_cache_saving"), fmt.money(saved), { t("kpi_cache_saving_detail") }),
		parts.kpi(t("kpi_requests"), fmt.count(req)),
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
		{ id = "model", head = t("col_model"), grow = 1, priority = 5 },
		{ id = "req", head = t("col_req"), align = "end", priority = 4 },
		{ id = "ttft", head = t("col_ttft"), align = "end", priority = 5 },
		{ id = "dur", head = t("col_duration"), align = "end", priority = 3 },
		{ id = "tps", head = t("col_speed"), align = "end", priority = 4 },
		{ id = "hit", head = t("col_cache_hit"), priority = 2 },
		{ id = "saved", head = t("col_saving"), align = "end", priority = 1 },
	}
	return ui.col({
		parts.kpis(tiles),
		parts.panel(i18n.tf("ttft_per", parts.per(r)), { parts.trend(r, parts.get(d, "series"), "ttft", fmt.ms) }),
		parts.panel(t("panel_per_model"), { parts.table(cols, rows, t("empty_requests")) }),
	})
end

return view
