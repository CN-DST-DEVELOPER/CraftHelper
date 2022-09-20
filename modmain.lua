GLOBAL.setmetatable(
	env,
	{
		__index = function(t, k)
			return GLOBAL.rawget(GLOBAL, k)
		end
	}
)

if TheNet:IsDedicated() then
	return
end

local is_enable = GetModConfigData("is_enable") or true
local always_enable = GetModConfigData("always_enable") or false
local toggle_key = GLOBAL[string.upper(GetModConfigData("toggle_key"))] or 306
local talk_mode = GetModConfigData("talk_mode") or 2

local function EnableHelper()
	return (is_enable and not TheInput:IsKeyDown(toggle_key)) or (not is_enable and TheInput:IsKeyDown(toggle_key))
end

local CraftHelperFunction = {}

function CraftHelperFunction.CanBuildExceptMaterial(self, recipe)
	for i, v in ipairs(recipe.character_ingredients) do
		if not self:HasCharacterIngredient(v) then
			return false
		end
	end
	for i, v in ipairs(recipe.tech_ingredients) do
		if not self:HasTechIngredient(v) then
			return false
		end
	end
	return true
end

function CraftHelperFunction.CanMakeMaterial(self, IntermediateMaterials)
	for _, v in ipairs(IntermediateMaterials) do
		local has_recipe = false
		for _, recipe in pairs(AllRecipes) do
			if recipe.product == v.perfab and CraftHelperFunction.CanBuildExceptMaterial(self, recipe) then
				has_recipe = true
				table.insert(self.CraftHelper.Table, 1, {recipe = recipe, num = v.num})
				CraftHelperFunction.CountForMaterial(self, recipe, v.num)
			end
		end
		if not has_recipe then
			self.CraftHelper.cancraft = false
			self.CraftHelper.Materials[v.perfab] = (self.CraftHelper.Materials[v.perfab] or 0) + v.num
		end
	end
end

function CraftHelperFunction.CountForMaterial(self, recipe, count)
	local IntermediateMaterials = {}
	for i, v in ipairs(recipe.ingredients) do
		local amount = math.max(1, RoundBiasedUp(v.amount * self:IngredientMod())) * (count or 1)
		local enough, num_found = self.inst.replica.inventory:Has(v.type, amount)
		if not enough then
			table.insert(IntermediateMaterials, {perfab = v.type, num = amount - num_found})
		end
	end
	CraftHelperFunction.CanMakeMaterial(self, IntermediateMaterials)
end

AddClassPostConstruct(
	"components/builder_replica",
	function(self)
		local CanBuild_Original = self.CanBuild
		local MakeRecipeFromMenu_Original = self.MakeRecipeFromMenu
		local BufferBuild_Original = self.BufferBuild
		local function CraftHelperBuild(self, recipe, skin)
			self.prebuildrecipe = nil
			if not self:CanCraftHelperBuild(recipe.name) then
				return
			end

			self.craft_thread =
				StartThread(
				function()
					self.inst:ClearBufferedAction()
					for _, v in ipairs(self.CraftHelper.Table) do
						for i = 1, v.num do
							if self.inst:IsValid() and self:CanBuild(v.recipe.name) then
								MakeRecipeFromMenu_Original(self, v.recipe)
								Sleep(1.3)
							end
						end
					end
					if recipe.placer then
						if not self:IsBuildBuffered(recipe.name) then
							BufferBuild_Original(self, recipe.name)
						end
						if self:IsBuildBuffered(recipe.name) then
							ThePlayer.components.playercontroller:StartBuildPlacementMode(recipe, skin)
						end
					else
						MakeRecipeFromMenu_Original(self, recipe, skin)
					end
					KillThreadsWithID(self.craft_thread.id)
					self.craft_thread = nil
				end,
				"CraftHelperThread"
			)
		end

		function self:CanCraftHelperBuild(recipename)
			local recipe = GetValidRecipe(recipename)
			if recipe == nil then
				return false
			end
			self.CraftHelper = {
				Recipename = recipename,
				Table = {},
				cancraft = true,
				TargetSkin = "",
				Materials = {}
			}
			if not CraftHelperFunction.CanBuildExceptMaterial(self, recipe) then
				return false
			end
			if not self.classified.isfreebuildmode:value() then
				CraftHelperFunction.CountForMaterial(self, recipe, 1)
				return self.CraftHelper.cancraft
			end
			return true
		end

		self.CanBuild = function(self, recipename)
			if (always_enable and EnableHelper()) or recipename == self.prebuildrecipe then
				return self:CanCraftHelperBuild(recipename)
			else
				return CanBuild_Original(self, recipename)
			end
		end

		self.MakeRecipeFromMenu = function(self, recipe, skin)
			if not EnableHelper() then
				MakeRecipeFromMenu_Original(self, recipe, skin)
			else
				CraftHelperBuild(self, recipe, skin)
			end
		end

		self.BufferBuild = function(self, recipename)
			if not EnableHelper() then
				BufferBuild_Original(self, recipename)
			else
				CraftHelperBuild(self, AllRecipes[recipename])
			end
		end
	end
)

AddComponentPostInit(
	"playercontroller",
	function(self, inst)
		if inst ~= ThePlayer then
			return
		end

		local OnControl_Original = self.OnControl
		self.OnControl = function(self, control, down)
			OnControl_Original(self, control, down)
			if
				down and ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus() and
					ThePlayer.replica.builder.craft_thread and
					control and
					not TheInput:GetHUDEntityUnderMouse()
			 then
				KillThreadsWithID(ThePlayer.replica.builder.craft_thread.id)
				ThePlayer.replica.builder.craft_thread = nil
			end
		end
	end
)

local talk_cd = 3

local talk_functions = {
	[1] = function(str)
		TheNet:Say(str, false)
	end,
	[2] = function(str)
		TheNet:Say(str, true)
	end,
	[3] = function(str)
		ThePlayer.components.talker:Say(str, nil, nil, true)
	end,
	[4] = function(str)
	end
}

AddClassPostConstruct(
	"widgets/craftslot",
	function(self)
		self.lasttalk = 0
		local OnControl_Original = self.OnControl
		self.OnControl = function(self, control, down)
			if EnableHelper() and control == CONTROL_ACCEPT and down then
				ThePlayer.replica.builder.prebuildrecipe = self.recipe.name
				if
					talk_mode ~= 4 and not ThePlayer.replica.builder:CanCraftHelperBuild(self.recipe.name) and
						GetTime() - self.lasttalk > talk_cd
				 then
					local str = "制作" .. STRINGS.NAMES[string.upper(self.recipe.product)] .. "还需要"
					for k, v in pairs(ThePlayer.replica.builder.CraftHelper.Materials) do
						str = str .. v .. "个" .. STRINGS.NAMES[string.upper(k)]
					end
					talk_functions[talk_mode](str)
					self.lasttalk = GetTime()
				end
			end
			OnControl_Original(self, control, down)
		end
	end
)
