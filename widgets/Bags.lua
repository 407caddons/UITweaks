local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local bagFrame = Widgets.CreateWidgetFrame("Bags", "bags")
    bagFrame:SetScript("OnClick", function() ToggleAllBags() end)

    bagFrame.UpdateContent = function(self)
        local free = 0
        for i = 0, NUM_BAG_SLOTS do
            free = free + C_Container.GetContainerNumFreeSlots(i)
        end
        self.text:SetFormattedText("Bags: %d", free)
    end
end)
