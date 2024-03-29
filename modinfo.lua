name = "Craft Helper"
description =
	"自动从附近带有小木牌的箱子中获取制作材料，支持复杂物品自动制作材料\n\nAutomatically get materials from nearby boxes with minisign, and support the automatic compose ingredient for complex items"
author = "Fengying"
version = "2.0.9"
api_version_dst = 10
priority = -999999

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
all_clients_require_mod = true

mod_dependencies = {{workshop = "workshop-1595631294"}, {workshop = "workshop-2097358269"}}

configuration_options = {
	{
		label = "检测箱子距离\nDetect chest distance",
		hover = "一块地皮距离为4\nThe distance of a piece of land is 4",
		name = "distance",
		options = {
			{description = "10", data = 10},
			{description = "14", data = 14},
			{description = "18", data = 18},
			{description = "22", data = 22}
		},
		default = 14
	},
	-- {
	-- 	label = "在更新可建造列表时即使用本mod，而不只是建造时（可能导致卡顿）\nUse this mod while updating the buildable list, not just building (which may cause your client stuck)",
	-- 	name = "always_enable",
	-- 	options = {{description = "Yes", data = true}, {description = "No", data = false}},
	-- 	default = false
	-- },
	-- {
	-- 	label = "热键开关\nToggle key",
	-- 	name = "toggle_key",
	-- 	options = keylist,
	-- 	default = "KEY_LCtrl"
	-- },
	{
		label = "无法制作时说出你缺少的材料\nSpeak out if you are short of some materials",
		name = "talk_mode",
		options = {
			{description = "公频喊话 | global talk", data = 1},
			{description = "私聊喊话 | whisper talk", data = 2},
			{description = "官方默认 | default as normal", data = 0}
		},
		default = 1
	},
	{
		label = "讲话间隔\ntalk cd",
		name = "talk_cd",
		options = {
			{description = "0.5s", data = 0.5},
			{description = "1.5s", data = 1.5},
			{description = "3s", data = 3}
		},
		default = 0.5
	}
}
