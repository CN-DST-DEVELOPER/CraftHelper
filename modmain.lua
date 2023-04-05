GLOBAL.setmetatable(
	env,
	{
		__index = function(t, k)
			return GLOBAL.rawget(GLOBAL, k)
		end
	}
)

local distance = GetModConfigData("distance") or 14
local talk_mode = GetModConfigData("talk_mode", true) or 1
local talk_cd = GetModConfigData("talk_cd") or 0.5
------------------------------------------------------------------------------------------------------------------------------------
-- GLOBAL functions

local function pprint(...)
	print("Craft_Helper", ...)
end

local talk_functions = {
	[1] = function(str)
		TheNet:Say(str, false)
	end,
	[2] = function(str)
		TheNet:Say(str, true)
	end,
	[0] = function(str)
		local str = GetString(ThePlayer, "ANNOUNCE_CANNOT_BUILD", "NO_INGREDIENTS", true)
		if str ~= nil then
			local talker = ThePlayer.components.talker
			if talker ~= nil then
				talker:Say(str)
			end
		end
	end
}

local minisigh_chest = {}
local Craft_Helper = {}

Craft_Helper.HasCraftingIngredientFromMinisignChest = function(player, item, amount)
	local total_num_found = 0
	for i, chest in pairs(minisigh_chest) do
		if chest:IsValid() and chest:IsNear(player, distance) and not player.components.inventory.opencontainers[chest] then
			-- local copy = SpawnPrefab(v.prefab)
			-- tname = copy ~= nil and (copy.drawnameoverride or copy:GetBasicDisplayName()) or ""
			-- copy:Remove()
			if chest.components.smart_minisign.sign._imagename:value() == STRINGS.NAMES[string.upper(item)] then
				local enough, num_found = chest.components.container:Has(item, amount - total_num_found)
				total_num_found = total_num_found + num_found
				if enough then
					return true, total_num_found
				end
			end
		end
	end
	return false, total_num_found
end

Craft_Helper.CanCraftIngredient = function(owner, recipe, tech_level, num)
	num = num or 1
	local can_craft = true
	local short_table =
		setmetatable(
		{},
		{
			__index = function()
				return 0
			end
		}
	)
	for i, ing in ipairs(recipe.ingredients) do
		local amt = math.max(1, RoundBiasedUp(ing.amount * owner.components.builder.ingredientmod)) * num
		local _, num_found_chest = Craft_Helper.HasCraftingIngredientFromMinisignChest(owner, ing.type, amt)
		local _, num_found_inv = owner.components.inventory:Has(ing.type, amt - num_found_chest, true)
		local short = amt - num_found_chest - num_found_inv
		if short > 0 then
			local ing_recipe = GetValidRecipe(ing.type)
			if
				ing_recipe ~= nil and
					(owner.replica.builder:KnowsRecipe(ing_recipe) or
						(CanPrototypeRecipe(ing_recipe.level, tech_level) and owner.replica.builder:CanLearn(ing.type)))
			 then
				for i, v in ipairs(ing_recipe.ingredients) do
					local ing_amt = math.max(1, RoundBiasedUp(v.amount * owner.components.builder.ingredientmod)) * short
					local _, ing_num_found_chest = Craft_Helper.HasCraftingIngredientFromMinisignChest(owner, v.type, ing_amt)
					local _, ing_num_found_inv = owner.components.inventory:Has(v.type, amt - ing_num_found_chest, true)
					ing_short = ing_amt - ing_num_found_chest - ing_num_found_inv
					if ing_short > 0 then
						local ing_can_craft, ing_short_table = Craft_Helper.CanCraftIngredient(owner, ing_recipe, tech_level, ing_short)
						can_craft = can_craft and ing_can_craft
						for key, value in pairs(ing_short_table) do
							short_table[key] = short_table[key] + value
						end
					end
				end
				for i, v in ipairs(ing_recipe.character_ingredients) do
					if not owner.components.builder:HasCharacterIngredient(v) then
						can_craft = false
					end
				end
				for i, v in ipairs(ing_recipe.tech_ingredients) do
					if not owner.components.builder:HasTechIngredient(v) then
						can_craft = false
					end
				end
			else
				short_table[ing.type] = short
				can_craft = false
			end
		end
	end
	return can_craft, short_table
end

Craft_Helper.MakeIngredient = function(self, recipe)
	for i, ing in ipairs(recipe.ingredients) do
		local ing_recipe = GetValidRecipe(ing.type)
		if
			ing_recipe ~= nil and
				not self.inst.components.inventory:Has(ing.type, math.max(1, RoundBiasedUp(ing.amount * self.ingredientmod)), true)
		 then
			if self:HasIngredients(ing_recipe) then
				--Need to determine this NOW before calling async MakeRecipe
				local knows_no_temp = self:KnowsRecipe(ing_recipe, true)
				local canproto_no_temp = CanPrototypeRecipe(ing_recipe.level, self.accessible_tech_trees_no_temp)
				local canlearn = self:CanLearn(ing_recipe.name)
				local usingtempbonus = not knows_no_temp and not canproto_no_temp

				if self:KnowsRecipe(ing_recipe) then
					self:MakeRecipe(
						ing_recipe,
						nil,
						nil,
						ValidateRecipeSkinRequest(self.inst.userid, ing_recipe.product, nil),
						function()
							if usingtempbonus then
								self:ConsumeTempTechBonuses()
							end

							if self.freebuildmode then
								--V2C: free-build should still trigger prototyping
								if
									not table.contains(self.recipes, ing_recipe.name) and
										CanPrototypeRecipe(ing_recipe.level, self.accessible_tech_trees)
								 then
									self:ActivateCurrentResearchMachine(ing_recipe)
								end
							elseif not knows_no_temp and canproto_no_temp and canlearn then
								--assert(not usingtempbonus) --sanity check
								--V2C: for recipes known through temp bonus buff,
								--     but can be prototyped without consuming it
								self:ActivateCurrentResearchMachine(ing_recipe)
								self:UnlockRecipe(ing_recipe.name)
							elseif not ing_recipe.nounlock then
								--V2C: for recipes known through tech bonus, still
								--     want to unlock in case we reroll characters
								self:AddRecipe(ing_recipe.name)
							else
								self:ActivateCurrentResearchMachine(ing_recipe)
							end
						end
					)
				elseif canlearn and CanPrototypeRecipe(ing_recipe.level, self.accessible_tech_trees) then
					self:MakeRecipe(
						ing_recipe,
						nil,
						nil,
						ValidateRecipeSkinRequest(self.inst.userid, ing_recipe.product, nil),
						function()
							if usingtempbonus then
								self:ConsumeTempTechBonuses()
							end
							self:ActivateCurrentResearchMachine(ing_recipe)
							self:UnlockRecipe(ing_recipe.name)
						end
					)
				end
			else
				Craft_Helper.MakeIngredient(self, ing_recipe)
			end
		end
	end
end

------------------------------------------------------------------------------------------------------------------------------------
-- Hacking

AddPlayerPostInit(
	function(inst)
		inst.last_craft_helper_talk = 0
		inst.craft_helper_string = net_string(inst.GUID, "craft_helper.string", "craft_helper_stringdirty")
		inst.craft_helper_string:set_local("")
		if not TheNet:GetIsServer() then
			inst:ListenForEvent(
				"craft_helper_stringdirty",
				function(inst)
					local str2 = inst.craft_helper_string:value()
					local str = DecodeAndUnzipString(inst.craft_helper_string:value())
					if str ~= nil then
						talk_functions[talk_mode](str)
					end
				end
			)
		end
	end
)

if TheNet:GetIsServer() then
	if TUNING.SMART_SIGN_DRAW_ENABLE then
		AddClassPostConstruct(
			"components/smart_minisign",
			function(self)
				-- self.inst.components.container.excludefromcrafting = true
				minisigh_chest[self.inst.GUID] = self.inst
				self.inst:ListenForEvent(
					"onremove",
					function()
						minisigh_chest[self.inst.GUID] = nil
					end
				)
			end
		)
	end

	AddClassPostConstruct(
		"components/builder",
		function(self)
			function self:MakeRecipeFromMenu(recipe, skin)
				if self:HasIngredients(recipe) then
					if recipe.placer == nil then
						--Need to determine this NOW before calling async MakeRecipe
						local knows_no_temp = self:KnowsRecipe(recipe, true)
						local canproto_no_temp = CanPrototypeRecipe(recipe.level, self.accessible_tech_trees_no_temp)
						local canlearn = self:CanLearn(recipe.name)
						local usingtempbonus = not knows_no_temp and not canproto_no_temp

						if self:KnowsRecipe(recipe) then
							self:MakeRecipe(
								recipe,
								nil,
								nil,
								ValidateRecipeSkinRequest(self.inst.userid, recipe.product, skin),
								function()
									if usingtempbonus then
										self:ConsumeTempTechBonuses()
									end

									if self.freebuildmode then
										--V2C: free-build should still trigger prototyping
										if
											not table.contains(self.recipes, recipe.name) and
												CanPrototypeRecipe(recipe.level, self.accessible_tech_trees)
										 then
											self:ActivateCurrentResearchMachine(recipe)
										end
									elseif not knows_no_temp and canproto_no_temp and canlearn then
										--assert(not usingtempbonus) --sanity check
										--V2C: for recipes known through temp bonus buff,
										--     but can be prototyped without consuming it
										self:ActivateCurrentResearchMachine(recipe)
										self:UnlockRecipe(recipe.name)
									elseif not recipe.nounlock then
										--V2C: for recipes known through tech bonus, still
										--     want to unlock in case we reroll characters
										self:AddRecipe(recipe.name)
									else
										self:ActivateCurrentResearchMachine(recipe)
									end
								end
							)
						elseif canlearn and CanPrototypeRecipe(recipe.level, self.accessible_tech_trees) then
							self:MakeRecipe(
								recipe,
								nil,
								nil,
								ValidateRecipeSkinRequest(self.inst.userid, recipe.product, skin),
								function()
									if usingtempbonus then
										self:ConsumeTempTechBonuses()
									end
									self:ActivateCurrentResearchMachine(recipe)
									self:UnlockRecipe(recipe.name)
								end
							)
						end
					end
				else
					Craft_Helper.MakeIngredient(self, recipe)
				end
			end

			if not TUNING.SMART_SIGN_DRAW_ENABLE then
				TheNet:SystemMessage("[Craft Helper] Missing required mod <Smart Minisign> id 1595631294")
				return
			end

			local function GetCraftingIngredientFromMinisignChest(item, amount, reverse_search_order)
				local crafting_items = {}
				local total_num_found = 0
				for i, chest in pairs(minisigh_chest) do
					if chest:IsValid() and chest:IsNear(self.inst, distance) then
						if chest.components.smart_minisign.sign._imagename:value() == STRINGS.NAMES[string.upper(item)] then
							local container = chest.components.container or chest.components.inventory
							if container then
								for k, v in pairs(container:GetCraftingIngredient(item, amount - total_num_found, reverse_search_order)) do
									crafting_items[k] = v
									total_num_found = total_num_found + v
								end
							end
							if total_num_found >= amount then
								break
							end
						end
					end
				end
				return crafting_items, total_num_found
			end

			function self:HasIngredients(recipe)
				if type(recipe) == "string" then
					recipe = GetValidRecipe(recipe)
				end
				if recipe ~= nil then
					if self.freebuildmode then
						return true
					end
					for i, v in ipairs(recipe.ingredients) do
						local amt = math.max(1, RoundBiasedUp(v.amount * self.ingredientmod))
						local enough, num_found = Craft_Helper.HasCraftingIngredientFromMinisignChest(self.inst, v.type, amt)
						if not enough and not self.inst.components.inventory:Has(v.type, amt - num_found, true) then
							return false
						end
					end
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

				return false
			end

			function self:GetIngredients(recname)
				local recipe = AllRecipes[recname]
				if recipe then
					local ingredients = {}
					local discounted = false
					for k, v in pairs(recipe.ingredients) do
						if v.amount > 0 then
							local amt = math.max(1, RoundBiasedUp(v.amount * self.ingredientmod))
							local crafting_items, total_num_found = GetCraftingIngredientFromMinisignChest(v.type, amt, true)
							if total_num_found < amt then
								local items = self.inst.components.inventory:GetCraftingIngredient(v.type, amt - total_num_found)

								for k, v in pairs(items) do
									crafting_items[k] = v
								end
							end

							ingredients[v.type] = crafting_items
							if amt < v.amount then
								discounted = true
							end
						end
					end
					return ingredients, discounted
				end
			end
		end
	)
end
if TheNet:GetIsClient() or TheNet:GetServerIsClientHosted() then
	GLOBAL.DoRecipeClick = function(owner, recipe, skin)
		if recipe ~= nil and owner ~= nil and owner.replica.builder ~= nil then
			if skin == recipe.name then
				skin = nil
			end
			if owner:HasTag("busy") or owner.replica.builder:IsBusy() then
				return true
			end
			if owner.components.playercontroller ~= nil then
				local iscontrolsenabled, ishudblocking = owner.components.playercontroller:IsEnabled()
				if not (iscontrolsenabled or ishudblocking) then
					--Ignore button click when controls are disabled
					--but not just because of the HUD blocking input
					return true
				end
			end

			local buffered = owner.replica.builder:IsBuildBuffered(recipe.name)
			local knows = buffered or owner.replica.builder:KnowsRecipe(recipe)
			if buffered then
				SetCraftingAutopaused(false)
				Profile:SetLastUsedSkinForItem(recipe.name, skin)

				if recipe.placer == nil then
					owner.replica.builder:MakeRecipeFromMenu(recipe, skin)
				elseif owner.components.playercontroller ~= nil then
					owner.components.playercontroller:StartBuildPlacementMode(recipe, skin)
				end
				return false -- close the crafting menu
			elseif knows then
				SendModRPCToServer(MOD_RPC["craft_helper"]["has_ingredients"], knows, recipe.name, skin)
				return true
			else
				local tech_level = owner.replica.builder:GetTechTrees()
				if CanPrototypeRecipe(recipe.level, tech_level) then
					SendModRPCToServer(MOD_RPC["craft_helper"]["has_ingredients"], knows, recipe.name, skin)
					return true
				else
					return true, recipe.nounlock and "NO_STATION" or "NO_TECH"
				end
			end
		end
	end

	AddClassPostConstruct(
		"widgets/redux/craftingmenu_details",
		function(self)
			local UpdateBuildButton_Original = self.UpdateBuildButton
			self.UpdateBuildButton = function(...)
				UpdateBuildButton_Original(...)
				self.build_button_root.button:Enable()
			end
		end
	)
end

------------------------------------------------------------------------------------------------------------------------------------
-- RPC
AddModRPCHandler(
	"craft_helper",
	"has_ingredients",
	function(inst, knows, name, skin)
		local recipe = GetValidRecipe(name)
		if inst.replica.builder:HasIngredients(recipe) then
			SendModRPCToClient(CLIENT_MOD_RPC["craft_helper"]["do_craft"], inst.userid, knows, recipe.name, skin)
		else
			-- check if we can craft sub ingredients
			local tech_level = inst.replica.builder:GetTechTrees()
			local can_craft, short_table = Craft_Helper.CanCraftIngredient(inst, recipe, tech_level, 1)
			if can_craft then
				inst.replica.builder:MakeRecipeFromMenu(recipe, skin) -- tell the server to build the current recipe, not the ingredient
				return
			end

			if GetTime() - inst.last_craft_helper_talk > talk_cd then
				local str = "制作" .. STRINGS.NAMES[string.upper(recipe.product)] .. "还需要"
				for k, v in pairs(short_table) do
					str = str .. v .. "个" .. STRINGS.NAMES[string.upper(k)]
				end
				-- SendModRPCToClient(CLIENT_MOD_RPC["craft_helper"]["do_craft"], str)
				inst.craft_helper_string:set(ZipAndEncodeString(str))
				inst.last_craft_helper_talk = GetTime()
			end
		end
	end
)

-- builder need to run on client
local lastsoundtime = nil
AddClientModRPCHandler(
	"craft_helper",
	"do_craft",
	function(knows, name, skin)
		local recipe = GetValidRecipe(name)
		local already_buffered = ThePlayer.replica.builder:IsBuildBuffered(recipe.name)

		SetCraftingAutopaused(false)
		Profile:SetLastUsedSkinForItem(recipe.name, skin)
		if recipe.placer == nil then
			ThePlayer.replica.builder:MakeRecipeFromMenu(recipe, skin)
			if knows or recipe.nounlock then
				return
			end
		elseif ThePlayer.components.playercontroller ~= nil then
			--owner.HUD.controls.craftingmenu.tabs:DeselectAll()
			ThePlayer.replica.builder:BufferBuild(recipe.name)
			if not ThePlayer.replica.builder:IsBuildBuffered(recipe.name) then
				return
			end
			ThePlayer.components.playercontroller:StartBuildPlacementMode(recipe, skin)
			if not knows then
				if ThePlayer.components.builder ~= nil then
					ThePlayer.components.builder:ActivateCurrentResearchMachine(recipe)
					ThePlayer.components.builder:UnlockRecipe(recipe.name)
				end
			end
		end
		if not knows and not recipe.nounlock then
			if lastsoundtime == nil or GetStaticTime() - lastsoundtime >= 1 then
				lastsoundtime = GetStaticTime()
				TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/research_unlock")
			end
		end
		if recipe.placer and (already_buffered or Profile:GetCraftingMenuBufferedBuildAutoClose()) then
			ThePlayer.HUD:CloseCrafting()
		end
	end
)

-- AddClientModRPCHandler(
-- 	"craft_helper",
-- 	"talk",
-- 	function(str)
-- 		talk_functions[talk_mode](str)
-- 	end
-- )
