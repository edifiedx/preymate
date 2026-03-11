---------------------------------------------------------------------
-- PreyMate_Minimap.lua — Minimap button (LibDBIcon-1.0)
---------------------------------------------------------------------
local PM = PreyMate

local PREY_LEVELS = { "Normal", "Hard", "Nightmare" }

local ACCEPT_MODE_OPTIONS = {
    { text = "Hold Shift to accept",      value = 1 },
    { text = "Hold Shift to skip accept", value = 2 },
}
local REWARD_OPTIONS = {
    { text = "Gold",           value = 1 },
    { text = "Voidlight Marl", value = 2 },
    { text = "Dawncrest",      value = 3 },
    { text = "Anguish",        value = 4 },
}

---------------------------------------------------------------------
-- Right-click context menu
---------------------------------------------------------------------
local function ShowContextMenu(anchor)
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle("|cffcc3333Prey|rMate")
        root:CreateButton("Track Now", function() PM:Track() end)
        root:CreateDivider()

        -- Auto-accept submenu (hunt level + accept mode nested within)
        local autoAccept = root:CreateCheckbox("Auto-accept",
            function() return PM:GetProfile().autoAccept end,
            function()
                local p = PM:GetProfile()
                p.autoAccept = not p.autoAccept
            end
        )
        local huntLevel = autoAccept:CreateButton("Hunt Level")
        for i, levelName in ipairs(PREY_LEVELS) do
            local idx = i
            huntLevel:CreateRadio(levelName,
                function() return PM:GetProfile().preyLevel == idx end,
                function()
                    PM:GetProfile().preyLevel = idx
                    if PM.levelDropdown then PM.levelDropdown:Refresh() end
                end
            )
        end
        for _, opt in ipairs(ACCEPT_MODE_OPTIONS) do
            local val = opt.value
            autoAccept:CreateRadio(opt.text,
                function() return PM:GetProfile().autoAcceptMode == val end,
                function()
                    PM:GetProfile().autoAcceptMode = val
                    if PM.acceptModeDropdown then PM.acceptModeDropdown:Refresh() end
                end
            )
        end

        root:CreateCheckbox("Auto-pay fee",
            function() return PM:GetProfile().autoPayFee end,
            function() 
                local p = PM:GetProfile()
                p.autoPayFee = not p.autoPayFee
            end
        )

        -- Auto-complete / auto-collect submenu
        root:CreateCheckbox("Auto-complete",
            function() return PM:GetProfile().autoComplete end,
            function() 
                local p = PM:GetProfile()
                p.autoComplete = not p.autoComplete
            end
        )

        local autoCollect = root:CreateCheckbox("Auto-collect reward",
            function() return PM:GetProfile().autoCollect end,
            function() 
                local p = PM:GetProfile()
                p.autoCollect = not p.autoCollect
            end
        )
        for _, opt in ipairs(REWARD_OPTIONS) do
            local val = opt.value
            autoCollect:CreateRadio(opt.text,
                function() return PM:GetProfile().autoCollectReward == val end,
                function()
                    PM:GetProfile().autoCollectReward = val
                    if PM.rewardDropdown then PM.rewardDropdown:Refresh() end
                end
            )
        end

        root:CreateDivider()

        -- Minimap toggle
        root:CreateCheckbox("Show minimap icon",
            function() return PM:GetProfile().showMinimapIcon end,
            function()
                local p = PM:GetProfile()
                p.showMinimapIcon = not p.showMinimapIcon
                PM:UpdateMinimapIcon()
            end
        )
        
        root:CreateDivider()

        root:CreateButton("Open Settings", function()
            if PM.settingsCategory then
                Settings.OpenToCategory(PM.settingsCategory.ID)
            end
        end)
    end)
end

---------------------------------------------------------------------
-- Minimap icon
---------------------------------------------------------------------
local iconLib

function PM:UpdateMinimapIcon()
    if not iconLib then return end
    local profile = self:GetProfile()
    PreyMateDB.minimap.hide = not profile.showMinimapIcon
    if PM.minimapCB then PM.minimapCB:SetChecked(profile.showMinimapIcon) end
    if profile.showMinimapIcon then
        iconLib:Show(PM.ADDON_NAME)
    else
        iconLib:Hide(PM.ADDON_NAME)
    end
end

local function InitMinimapIcon()
    local LibStub_ = _G["LibStub"]
    if not LibStub_ then return end

    local ldb   = LibStub_("LibDataBroker-1.1", true)
    iconLib     = LibStub_("LibDBIcon-1.0", true)
    if not ldb or not iconLib then return end

    local ldbObject = ldb:NewDataObject(PM.ADDON_NAME, {
        type  = "launcher",
        text  = "PreyMate",
        icon  = 7493985,
        OnClick = function(self, button)
            if button == "LeftButton" then
                PM:Track()
            elseif button == "RightButton" then
                ShowContextMenu(self)
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText(PM.PREFIX)
            tooltip:AddLine("Left-click to track Prey quest", 1, 1, 1)
            tooltip:AddLine("Right-click for options", 1, 1, 1)
            tooltip:Show()
        end,
    })

    -- Sync hide state before registering so the icon respects the saved setting
    local profile = PM:GetProfile()
    PreyMateDB.minimap.hide = not profile.showMinimapIcon

    iconLib:Register(PM.ADDON_NAME, ldbObject, PreyMateDB.minimap)
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == PM.ADDON_NAME then
        -- PreyMateDB is already initialised by PreyMate.lua's handler
        if not PreyMateDB.minimap then PreyMateDB.minimap = {} end
        InitMinimapIcon()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)