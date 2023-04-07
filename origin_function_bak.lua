---@diagnostic disable: undefined-global, undefined-field
-- Backup for raw function been hacked in offical files while this mod create
-- compare this with modmain and update this mod while game updated
-- current game version: 522521

-------------------------------------------------------------------------------------------------------------------------
-- components/builder.lua

function Builder:GetIngredients(recname)
    local recipe = AllRecipes[recname]
    if recipe then
        local ingredients = {}
        local discounted = false
        for k, v in pairs(recipe.ingredients) do
            if v.amount > 0 then
                local amt = math.max(1, RoundBiasedUp(v.amount * self.ingredientmod))
                local items = self.inst.components.inventory:GetCraftingIngredient(v.type, amt)
                ingredients[v.type] = items
                if amt < v.amount then
                    discounted = true
                end
            end
        end
        return ingredients, discounted
    end
end

function Builder:HasIngredients(recipe)
    if type(recipe) == "string" then
        recipe = GetValidRecipe(recipe)
    end
    if recipe ~= nil then
        if self.freebuildmode then
            return true
        end
        for i, v in ipairs(recipe.ingredients) do
            if
                not self.inst.components.inventory:Has(
                    v.type,
                    math.max(1, RoundBiasedUp(v.amount * self.ingredientmod)),
                    true
                )
             then
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

function Builder:MakeRecipeFromMenu(recipe, skin)
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
        for i, ing in ipairs(recipe.ingredients) do
            local ing_recipe = GetValidRecipe(ing.type)
            if
                ing_recipe ~= nil and
                    not self.inst.components.inventory:Has(
                        ing.type,
                        math.max(1, RoundBiasedUp(ing.amount * self.ingredientmod)),
                        true
                    ) and
                    self:HasIngredients(ing_recipe)
             then
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
            end
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------
-- widgets/widgetutil.lua

local function CanCraftIngredient(owner, ing, tech_level)
    local ing_recipe = GetValidRecipe(ing.type)
    return ing_recipe ~= nil and
        not owner.replica.inventory:Has(
            ing.type,
            math.max(1, RoundBiasedUp(ing.amount * owner.replica.builder:IngredientMod())),
            true
        ) and
        (owner.replica.builder:KnowsRecipe(ing_recipe) or
            (CanPrototypeRecipe(ing_recipe.level, tech_level) and owner.replica.builder:CanLearn(ing.type))) and
        owner.replica.builder:HasIngredients(ing_recipe)
end

local lastsoundtime = nil
-- return values: "keep_crafting_menu_open", "error message"
function DoRecipeClick(owner, recipe, skin)
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
        local has_ingredients = buffered or owner.replica.builder:HasIngredients(recipe)

        if not has_ingredients and TheWorld.ismastersim then
            owner:PushEvent("cantbuild", {owner = owner, recipe = recipe})
            --You might have the materials now. Check again.
            has_ingredients = owner.replica.builder:HasIngredients(recipe)
        end

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
            if has_ingredients then
                --TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
                SetCraftingAutopaused(false)
                Profile:SetLastUsedSkinForItem(recipe.name, skin)

                if recipe.placer == nil then
                    owner.replica.builder:MakeRecipeFromMenu(recipe, skin)
                    return true
                elseif owner.components.playercontroller ~= nil then
                    --owner.HUD.controls.craftingmenu.tabs:DeselectAll()
                    owner.replica.builder:BufferBuild(recipe.name)
                    if not owner.replica.builder:IsBuildBuffered(recipe.name) then
                        return true
                    end
                    owner.components.playercontroller:StartBuildPlacementMode(recipe, skin)
                end
            else
                -- check if we can craft sub ingredients
                local tech_level = owner.replica.builder:GetTechTrees()
                for i, ing in ipairs(recipe.ingredients) do
                    if CanCraftIngredient(owner, ing, tech_level) then
                        owner.replica.builder:MakeRecipeFromMenu(recipe, skin) -- tell the server to build the current recipe, not the ingredient
                        return true
                    end
                end

                return true, "NO_INGREDIENTS"
            end
        else
            local tech_level = owner.replica.builder:GetTechTrees()
            if CanPrototypeRecipe(recipe.level, tech_level) then
                if has_ingredients then
                    SetCraftingAutopaused(false)
                    Profile:SetLastUsedSkinForItem(recipe.name, skin)

                    if recipe.placer == nil then
                        owner.replica.builder:MakeRecipeFromMenu(recipe, skin)
                        if recipe.nounlock then
                            return true
                        end
                    elseif owner.components.playercontroller ~= nil then
                        owner.replica.builder:BufferBuild(recipe.name)
                        if not owner.replica.builder:IsBuildBuffered(recipe.name) then
                            return true
                        end
                        owner.components.playercontroller:StartBuildPlacementMode(recipe, skin)
                        if owner.components.builder ~= nil then
                            owner.components.builder:ActivateCurrentResearchMachine(recipe)
                            owner.components.builder:UnlockRecipe(recipe.name)
                        end
                    end
                    if not recipe.nounlock then
                        if lastsoundtime == nil or GetStaticTime() - lastsoundtime >= 1 then
                            lastsoundtime = GetStaticTime()
                            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/research_unlock")
                        end
                    end

                    return recipe.placer == nil -- close the crafting menu if there is a placer
                else
                    -- check if we can craft sub ingredients
                    for i, ing in ipairs(recipe.ingredients) do
                        if CanCraftIngredient(owner, ing, tech_level) then
                            owner.replica.builder:MakeRecipeFromMenu(recipe, skin) -- tell the server to build the current recipe, not the ingredient
                            return true
                        end
                    end

                    return true, "NO_INGREDIENTS"
                end
            else
                return true, recipe.nounlock and "NO_STATION" or "NO_TECH"
            end
        end
    end
end
