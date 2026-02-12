local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local specFrame = Widgets.CreateWidgetFrame("Spec", "spec")
    specFrame:RegisterForClicks("AnyUp")

    specFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Change Spec
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Switch Specialization")
                local currentSpecIndex = GetSpecialization()
                for i = 1, GetNumSpecializations() do
                    local id, name, _, icon = GetSpecializationInfo(i)
                    if id then
                        local btn = rootDescription:CreateButton(name,
                            function() C_SpecializationInfo.SetSpecialization(i) end)
                        if currentSpecIndex == i then
                            btn:SetEnabled(false)
                        end
                    end
                end
                rootDescription:CreateButton("Cancel", function() end)
            end)
        elseif button == "RightButton" then
            -- Change Loot Spec
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Loot Specialization")

                local currentLootSpec = GetLootSpecialization()

                -- Current Spec Option (0)
                local currentSpecIndex = GetSpecialization()
                local _, currentSpecName = GetSpecializationInfo(currentSpecIndex)
                local btn0 = rootDescription:CreateButton(
                "Current Specialization (" .. (currentSpecName or "Unknown") .. ")",
                    function() SetLootSpecialization(0) end)
                if currentLootSpec == 0 then
                    btn0:SetEnabled(false)
                end

                for i = 1, GetNumSpecializations() do
                    local id, name, _, icon = GetSpecializationInfo(i)
                    if id then
                        local btn = rootDescription:CreateButton(name, function() SetLootSpecialization(id) end)
                        if currentLootSpec == id then
                            btn:SetEnabled(false)
                        end
                    end
                end
                rootDescription:CreateButton("Cancel", function() end)
            end)
        end
    end)

    specFrame.UpdateContent = function(self)
        local currentSpecIndex = GetSpecialization()
        if currentSpecIndex then
            local currentSpecId, _, _, currentSpecIcon = GetSpecializationInfo(currentSpecIndex)
            local lootSpecId = GetLootSpecialization()

            local lootSpecIcon = currentSpecIcon
            if lootSpecId ~= 0 then
                local _, _, _, icon = GetSpecializationInfoByID(lootSpecId)
                lootSpecIcon = icon
            end

            if currentSpecIcon and lootSpecIcon then
                self.text:SetFormattedText("|T%s:16:16|t |T%s:16:16|t", currentSpecIcon, lootSpecIcon)
            end
        end
    end
end)
