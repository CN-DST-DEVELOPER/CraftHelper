name = "Craft Helper"
description =
	"自动制作合成时需要的中间产品，并统计你缺少的基础材料\nAutomatic production of intermediate products needed for synthesis, and statistics of the basic materials you lack"
author = "Fengying"
version = "1.0.2"
api_version_dst = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
all_clients_require_mod = false
client_only_mod = true

local keys = {
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
	"F1",
	"F2",
	"F3",
	"F4",
	"F5",
	"F6",
	"F7",
	"F8",
	"F9",
	"F10",
	"F11",
	"F12",
	"LAlt",
	"RAlt",
	"LCtrl",
	"RCtrl",
	"LShift",
	"RShift",
	"Tab",
	"Capslock",
	"Space",
	"Minus",
	"Equals",
	"Backspace",
	"Insert",
	"Home",
	"Delete",
	"End",
	"Pageup",
	"Pagedown",
	"Print",
	"Scrollock",
	"Pause",
	"Period",
	"Slash",
	"Semicolon",
	"Leftbracket",
	"Rightbracket",
	"Backslash",
	"Up",
	"Down",
	"Left",
	"Right"
}
local keylist = {}
for i = 1, #keys do
	keylist[i] = {description = keys[i], data = "KEY_" .. keys[i]}
end
keylist[#keylist + 1] = {description = "Disabled", data = false}

configuration_options = {
	{
		label = "默认启用这个mod\nEnable on default",
		name = "is_enable",
		options = {{description = "Yes", data = true}, {description = "No", data = false}},
		default = true
	},
	{
		label = "在更新可建造列表时即使用本mod，而不只是建造时（可能导致卡顿）\nUse this mod while updating the buildable list, not just building (which may cause your client stuck)",
		name = "always_enable",
		options = {{description = "Yes", data = true}, {description = "No", data = false}},
		default = false
	},
	{
		label = "热键开关\nToggle key",
		name = "toggle_key",
		options = keylist,
		default = "KEY_LCtrl"
	},
	{
		label = "说出你缺少的材料\nTalk if you need new material",
		name = "talk_mode",
		options = {
			{description = "公频喊话 | global talk", data = 1},
			{description = "私聊喊话 | whisper talk", data = 2},
			{description = "只有自己能看见 | yourself only", data = 3},
			{description = "不讲话 | no talk", data = 4}
		},
		default = 2
	}
}
