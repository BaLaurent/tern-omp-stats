--!strict
-- Window half: the palette command that switches the interface between French and English.
-- The language is saved in `tern.kv`, which the block (host half) reads too; open blocks are told to redraw.

local i18n = require("./lib/i18n")

-- The block titles its pane "OMP Stats · <tab> · <period>" (see host.luau); that is what identifies it.
local TITLE = "OMP Stats · "

local function refresh_open_blocks(cx: WindowCx)
	for _, pane in cx.session:panes() do
		if string.sub(pane.title, 1, #TITLE) == TITLE then
			cx.session:event(pane.pane, { ev = "action", act = "lang" })
		end
	end
end

local register_commands: () -> ()

register_commands = function()
	tern.command({
		id = "lang",
		title = i18n.t("cmd_lang"),
		icon = "globe",
		run = function(cx)
			i18n.toggle()
			-- The palette title is in the language that was current when it was registered.
			register_commands()
			cx:toast("info", i18n.t("lang_switched"))
			refresh_open_blocks(cx)
		end,
	})
end

register_commands()
