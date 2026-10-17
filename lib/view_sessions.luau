--!strict
-- Sessions tab: the most recently active sessions of the period.

local fmt = require("./fmt")
local parts = require("./parts")
local ranges = require("./ranges")

local view = {}

function view.render(d: { [string]: { any } }, _r: ranges.Range, _cols: number): Node
	local rows: { { Cell } } = {}
	local sessions: { any } = d.rows or {}
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
		{ id = "started", head = "Début", priority = 5 },
		{ id = "folder", head = "Projet", grow = 1, priority = 4, truncate = "start" },
		{ id = "span", head = "Durée", align = "end", priority = 3 },
		{ id = "req", head = "Req.", align = "end", priority = 4 },
		{ id = "tot", head = "Tokens", align = "end", priority = 2 },
		{ id = "cost", head = "Coût", align = "end", priority = 5 },
		{ id = "models", head = "Modèles", priority = 1, truncate = "end" },
	}
	return parts.panel("Sessions récentes", { parts.table(cols, rows, "Aucune session sur cette période.") })
end

return view
