--!strict
local check = require("./check")
local stub = require("./tern_stub")

local h = stub.host(".", "/nonexistent", {}, "fr_FR.UTF-8")
local i18n = h.require("lib/i18n")
local parts = h.require("lib/parts")

-- Both languages carry the same keys, and each key the same placeholders, so no screen can lose a value.
local fr, en = i18n.keys("fr"), i18n.keys("en")
check.eq(fr, en, "French and English have the same keys")
local function placeholders(text: string): { string }
	local out = {}
	for spec in string.gmatch(text, "%%[sd]") do
		table.insert(out, spec)
	end
	return out
end
for _, key in fr do
	h.kv.lang = "fr"
	local f = i18n.t(key)
	h.kv.lang = "en"
	local e = i18n.t(key)
	check.eq(placeholders(f), placeholders(e), `key {key}: same placeholders in both languages`)
	check.eq(f ~= "" and e ~= "", true, `key {key}: no empty text`)
end

-- Saved choice wins over the locale; an unknown saved value is ignored; toggling flips and saves.
h.kv.lang = "en"
check.eq(i18n.lang(), "en", "saved English beats the French locale")
h.kv.lang = "de"
check.eq(i18n.lang(), "fr", "unknown saved language falls back to the locale")
h.kv.lang = nil
check.eq(i18n.toggle(), "en", "toggle from the locale's French")
check.eq({ h.kv.lang, i18n.toggle(), h.kv.lang }, { "en", "fr", "fr" }, "toggle flips and saves")
check.eq(i18n.t("no_such_key"), "no_such_key", "unknown key shows itself")

-- Relative ages and the period name, in both languages.
local HOUR = 3600000
h.kv.lang = "fr"
check.eq(
	{ parts.ago(10000), parts.ago(300000), parts.ago(3 * HOUR), parts.ago(72 * HOUR) },
	{ "à l'instant", "il y a 5 min", "il y a 3 h", "il y a 3 j" },
	"ages in French"
)
check.eq({ parts.period({ id = "7d", key = "2", unit = "day", n = 7 }), parts.period({ id = "24h", key = "1", unit = "hour", n = 24 }) }, { "7 j", "24 h" }, "periods in French")
h.kv.lang = "en"
check.eq(
	{ parts.ago(10000), parts.ago(300000), parts.ago(3 * HOUR), parts.ago(72 * HOUR) },
	{ "just now", "5 min ago", "3 h ago", "3 d ago" },
	"ages in English"
)
check.eq({ parts.period({ id = "7d", key = "2", unit = "day", n = 7 }), parts.period({ id = "24h", key = "1", unit = "hour", n = 24 }) }, { "7 d", "24 h" }, "periods in English")
