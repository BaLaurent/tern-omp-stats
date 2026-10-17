--!strict
-- Interface language, French or English. The choice lives in `tern.kv` ("lang"), which the host half (the block)
-- and the window half (the palette command) both read, so a switch made in one shows in the other. Unset, it
-- follows the locale: `fr*` gives French, anything else English.

local STR: { [string]: { [string]: string } } = {
	fr = {
		-- tabs and periods
		tab_overview = "Vue d'ensemble",
		tab_models = "Modèles",
		tab_projects = "Projets",
		tab_performance = "Performance",
		tab_tools = "Outils",
		tab_sessions = "Sessions",
		unit_hour = "h",
		unit_day = "j",
		per_hour = "par heure",
		per_day = "par jour",
		-- block chrome
		loading = "Chargement des statistiques…",
		render_failed = "Affichage impossible : %s",
		db_missing = "Base introuvable : %s. Lancez une fois « omp stats » pour la créer.",
		refreshing = "⟳ actualisation",
		refresh_failed = "dernière actualisation en échec : %s",
		last_request = "dernière requête omp %s",
		hints = "1-4 période  ←/→ onglet  r actualiser  g langue",
		lang_button = "EN",
		-- palette command
		cmd_lang = "Changer de langue (FR/EN)",
		lang_switched = "Langue : français",
		-- ages
		ago_now = "à l'instant",
		ago_min = "il y a %d min",
		ago_hour = "il y a %d h",
		ago_day = "il y a %d j",
		-- database errors
		err_timeout = "requête trop longue (timeout)",
		err_unreadable = "réponse sqlite3 illisible",
		err_failed = "sqlite3 a échoué (code %d)",
		err_no_sqlite = "sqlite3 introuvable",
		-- shared
		vs_previous = "vs période préc.",
		no_data = "aucune donnée sur la période",
		peak = "pic",
		empty_requests = "Aucune requête omp sur cette période.",
		col_req = "Req.",
		col_tokens = "Tokens",
		col_cost = "Coût",
		col_share = "Part",
		col_err = "Err.",
		-- overview
		kpi_cost = "Coût",
		kpi_requests = "Requêtes",
		kpi_tokens = "Tokens",
		kpi_prompts = "Prompts",
		kpi_error_rate = "Taux d'erreur",
		kpi_cache = "Cache",
		errors_count = "%s erreurs",
		saved = "économie %s",
		unpriced = "%s requêtes sans prix",
		unpriced_note = "exclues du coût",
		cost_per = "Coût %s",
		requests_per = "Requêtes %s",
		mix_input = "Entrée",
		mix_output = "Sortie",
		mix_cache_read = "Cache lu",
		mix_cache_write = "Cache écrit",
		col_type = "Type",
		-- models
		panel_models = "Modèles",
		col_model = "Modèle",
		col_provider = "Provider",
		col_cache_read = "Cache lu",
		-- projects
		panel_projects = "Projets",
		col_project = "Projet",
		col_last = "Dernière req.",
		panel_agents = "Types d'agent",
		col_agent = "Type d'agent",
		-- performance
		kpi_ttft = "TTFT moyen",
		kpi_ttft_detail = "délai avant le 1er token",
		kpi_duration = "Durée moyenne",
		kpi_speed = "Débit",
		kpi_speed_detail = "tokens de sortie / s",
		kpi_cache_hit = "Cache hit",
		kpi_cache_saving = "Économie du cache",
		kpi_cache_saving_detail = "vs prompt sans cache",
		ttft_per = "TTFT moyen %s",
		panel_per_model = "Par modèle",
		col_ttft = "TTFT",
		col_duration = "Durée",
		col_speed = "Débit",
		col_cache_hit = "Cache hit",
		col_saving = "Économie",
		-- tools
		empty_tools = "Aucun appel d'outil sur cette période.",
		kpi_calls = "Appels",
		kpi_failure_rate = "Taux d'échec",
		failures_count = "%s échecs",
		kpi_distinct = "Outils distincts",
		panel_tools = "Outils",
		col_tool = "Outil",
		col_calls = "Appels",
		col_failures = "Échecs",
		col_failure_rate = "Taux d'échec",
		col_args = "Args moy.",
		col_result = "Résultat moy.",
		-- sessions
		panel_sessions = "Sessions récentes",
		empty_sessions = "Aucune session sur cette période.",
		col_start = "Début",
	},
	en = {
		tab_overview = "Overview",
		tab_models = "Models",
		tab_projects = "Projects",
		tab_performance = "Performance",
		tab_tools = "Tools",
		tab_sessions = "Sessions",
		unit_hour = "h",
		unit_day = "d",
		per_hour = "per hour",
		per_day = "per day",
		loading = "Loading statistics…",
		render_failed = "Cannot display: %s",
		db_missing = "Database not found: %s. Run \"omp stats\" once to create it.",
		refreshing = "⟳ refreshing",
		refresh_failed = "last refresh failed: %s",
		last_request = "latest omp request %s",
		hints = "1-4 period  ←/→ tab  r refresh  g language",
		lang_button = "FR",
		cmd_lang = "Switch language (FR/EN)",
		lang_switched = "Language: English",
		ago_now = "just now",
		ago_min = "%d min ago",
		ago_hour = "%d h ago",
		ago_day = "%d d ago",
		err_timeout = "query took too long (timeout)",
		err_unreadable = "unreadable sqlite3 output",
		err_failed = "sqlite3 failed (code %d)",
		err_no_sqlite = "sqlite3 not found",
		vs_previous = "vs prev. period",
		no_data = "no data in this period",
		peak = "peak",
		empty_requests = "No omp request in this period.",
		col_req = "Req.",
		col_tokens = "Tokens",
		col_cost = "Cost",
		col_share = "Share",
		col_err = "Err.",
		kpi_cost = "Cost",
		kpi_requests = "Requests",
		kpi_tokens = "Tokens",
		kpi_prompts = "Prompts",
		kpi_error_rate = "Error rate",
		kpi_cache = "Cache",
		errors_count = "%s errors",
		saved = "saved %s",
		unpriced = "%s requests without a price",
		unpriced_note = "not counted in the cost",
		cost_per = "Cost %s",
		requests_per = "Requests %s",
		mix_input = "Input",
		mix_output = "Output",
		mix_cache_read = "Cache read",
		mix_cache_write = "Cache write",
		col_type = "Type",
		panel_models = "Models",
		col_model = "Model",
		col_provider = "Provider",
		col_cache_read = "Cache read",
		panel_projects = "Projects",
		col_project = "Project",
		col_last = "Last req.",
		panel_agents = "Agent types",
		col_agent = "Agent type",
		kpi_ttft = "Avg TTFT",
		kpi_ttft_detail = "time to first token",
		kpi_duration = "Avg duration",
		kpi_speed = "Speed",
		kpi_speed_detail = "output tokens / s",
		kpi_cache_hit = "Cache hit",
		kpi_cache_saving = "Cache saving",
		kpi_cache_saving_detail = "vs prompt without cache",
		ttft_per = "Avg TTFT %s",
		panel_per_model = "Per model",
		col_ttft = "TTFT",
		col_duration = "Duration",
		col_speed = "Speed",
		col_cache_hit = "Cache hit",
		col_saving = "Saving",
		empty_tools = "No tool calls in this period.",
		kpi_calls = "Calls",
		kpi_failure_rate = "Failure rate",
		failures_count = "%s failures",
		kpi_distinct = "Distinct tools",
		panel_tools = "Tools",
		col_tool = "Tool",
		col_calls = "Calls",
		col_failures = "Failures",
		col_failure_rate = "Failure rate",
		col_args = "Avg args",
		col_result = "Avg result",
		panel_sessions = "Recent sessions",
		empty_sessions = "No sessions in this period.",
		col_start = "Start",
	},
}

local i18n = {}

--- "fr" or "en": the saved choice, else the locale's.
function i18n.lang(): string
	local ok, saved = pcall(tern.kv.get, "lang")
	if ok and (saved == "fr" or saved == "en") then
		return saved
	end
	local locale = string.lower(tern.getenv("LC_ALL") or tern.getenv("LANG") or "")
	return if string.sub(locale, 1, 2) == "fr" then "fr" else "en"
end

--- The text of `key` in the current language.
function i18n.t(key: string): string
	local pack = STR[i18n.lang()]
	return pack[key] or STR.en[key] or key
end

--- `t(key)` formatted with `string.format` arguments.
function i18n.tf(key: string, ...: any): string
	return string.format(i18n.t(key), ...)
end

function i18n.set(lang: string)
	if STR[lang] then
		tern.kv.set("lang", lang)
	end
end

--- Switches between French and English; returns the new language.
function i18n.toggle(): string
	local nxt = if i18n.lang() == "fr" then "en" else "fr"
	i18n.set(nxt)
	return nxt
end

--- Every key of `lang` (for the tests).
function i18n.keys(lang: string): { string }
	local out = {}
	for key in STR[lang] do
		table.insert(out, key)
	end
	table.sort(out)
	return out
end

return i18n
