-- PreyMate_Options.lua
local PM = PreyMate

local PREY_LEVELS = { "Normal", "Hard", "Nightmare" }
local REWARD_OPTIONS = {
    { text = "Gold",       value = 1 },
    { text = "Voidlight Marl", value = 2 },
    { text = "Dawncrest",  value = 3 },
    { text = "Anguish",    value = 4 },
}

---------------------------------------------------------------------
-- UI Helpers
---------------------------------------------------------------------
local checkCounter = 0

local function CreateCheckbox(parent, label, checked, onClick)
    local cb = CreateFrame("CheckButton", "PreyMateOpt" .. checkCounter, parent, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText(label)
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function(self)
        local val = self:GetChecked()
        PlaySound(val and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        onClick(self, val)
    end)
    checkCounter = checkCounter + 1
    return cb
end

local function CreateDropdown(parent, name, width, options, getValue, onSelect)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)

    local function Refresh()
        local val = getValue()
        for _, opt in ipairs(options) do
            if opt.value == val then
                UIDropDownMenu_SetText(dropdown, opt.text)
                break
            end
        end
    end

    UIDropDownMenu_Initialize(dropdown, function()
        local current = getValue()
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.checked = (opt.value == current)
            info.func = function()
                onSelect(opt.value)
                Refresh()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    dropdown.Refresh = Refresh
    Refresh()
    return dropdown
end

local function CreateButton(parent, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

---------------------------------------------------------------------
-- Settings Panel
---------------------------------------------------------------------
function PM:InitSettings()
    local panel = CreateFrame("Frame")
    panel.name = PM.ADDON_NAME

    local yOff = -16

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, yOff)
    title:SetText("|cffcc3333Prey|rMate")
    yOff = yOff - 24

    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 16, yOff)
    desc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(
        "PreyMate automatically tracks the Prey world quest when you accept a hunt, " ..
        "and retracks the hunt quest once your target has been revealed."
    )
    yOff = yOff - 40

    -- Slash command callout box
    local tipBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    tipBox:SetPoint("TOPLEFT", 16, yOff)
    tipBox:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    tipBox:SetHeight(32)
    tipBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    tipBox:SetBackdropColor(0.1, 0.1, 0.15, 0.8)
    tipBox:SetBackdropBorderColor(0.8, 0.7, 0.2, 1) -- gold border

    local tipText = tipBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tipText:SetPoint("CENTER")
    tipText:SetText("Use |cffffd100/pm track|r to manually find and supertrack the active Prey world quest.")

    yOff = yOff - 42

    -----------------------------------------------------------------
    -- Settings Section
    -----------------------------------------------------------------
    local settingsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    settingsHeader:SetPoint("TOPLEFT", 16, yOff)
    settingsHeader:SetText("Settings")
    yOff = yOff - 16

    local profile = PM:GetProfile()

    -----------------------------------------------------------------
    -- Auto Accept subsection
    -----------------------------------------------------------------
    local hrAcceptTop = panel:CreateTexture(nil, "ARTWORK")
    hrAcceptTop:SetPoint("TOPLEFT", 16, yOff)
    hrAcceptTop:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrAcceptTop:SetHeight(1)
    hrAcceptTop:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 14

    local autoAcceptHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoAcceptHeader:SetPoint("TOPLEFT", 16, yOff)
    autoAcceptHeader:SetText("Auto Accept")
    yOff = yOff - 24

    -- Enable auto-accept checkbox
    local autoAcceptCB = CreateCheckbox(panel, "Enable auto-accept", profile.autoAccept, function(self, checked)
        local p = PM:GetProfile()
        p.autoAccept = checked
    end)
    autoAcceptCB:SetPoint("TOPLEFT", 14, yOff)
    autoAcceptCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatically starts a Prey hunt when talking to Astalor Bloodsworn.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    autoAcceptCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yOff = yOff - 28

    -- Two-column labels: Hunt Level | Click behavior
    local huntLevelLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    huntLevelLabel:SetPoint("TOPLEFT", 18, yOff)
    huntLevelLabel:SetText("Hunt Level:")

    local clickBehaviorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    clickBehaviorLabel:SetPoint("TOPLEFT", 220, yOff)
    clickBehaviorLabel:SetText("Click behavior:")
    yOff = yOff - 20

    -- Two-column dropdowns: level (left) | accept mode (right)
    local levelOptions = {}
    for i, name in ipairs(PREY_LEVELS) do
        levelOptions[i] = { text = name, value = i }
    end
    local levelDropdown = CreateDropdown(panel, "PreyMateLevelDropdown", 120,
        levelOptions,
        function() return PM:GetProfile().preyLevel end,
        function(val) PM:GetProfile().preyLevel = val end
    )
    levelDropdown:SetPoint("TOPLEFT", 10, yOff)
    PM.levelDropdown = levelDropdown

    local acceptModeOptions = {
        { text = "Hold Shift to auto-accept",         value = PM.ACCEPT_SHIFT },
        { text = "Hold Shift to disable auto-accept", value = PM.ACCEPT_CLICK },
    }
    local acceptModeDropdown = CreateDropdown(panel, "PreyMateAcceptModeDropdown", 190,
        acceptModeOptions,
        function() return PM:GetProfile().autoAcceptMode end,
        function(val) PM:GetProfile().autoAcceptMode = val end
    )
    acceptModeDropdown:SetPoint("TOPLEFT", 210, yOff)
    PM.acceptModeDropdown = acceptModeDropdown
    yOff = yOff - 36

    -- Auto-pay fee checkbox
    local autoPayCB = CreateCheckbox(panel, "Auto-pay hunt fee", profile.autoPayFee, function(self, checked)
        local p = PM:GetProfile()
        p.autoPayFee = checked
    end)
    autoPayCB:SetPoint("TOPLEFT", 14, yOff)
    autoPayCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatically pays the hunt fee when prompted by Astalor Bloodsworn.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    autoPayCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yOff = yOff - 32

    local hrAcceptBottom = panel:CreateTexture(nil, "ARTWORK")
    hrAcceptBottom:SetPoint("TOPLEFT", 16, yOff)
    hrAcceptBottom:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrAcceptBottom:SetHeight(1)
    hrAcceptBottom:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 16

    -- Auto-complete checkbox
    local autoCompleteCB = CreateCheckbox(panel, "Auto-complete hunt quest", profile.autoComplete, function(self, checked)
        local p = PM:GetProfile()
        p.autoComplete = checked
    end)
    autoCompleteCB:SetPoint("TOPLEFT", 14, yOff)
    autoCompleteCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatically turns in the hunt quest when your Prey target is slain.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    autoCompleteCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yOff = yOff - 28

    -- Auto-collect checkbox + reward dropdown (indented, sub-option of auto-complete)
    local autoCollectCB = CreateCheckbox(panel, "Auto-collect reward:", profile.autoCollect, function(self, checked)
        local p = PM:GetProfile()
        p.autoCollect = checked
    end)
    autoCollectCB:SetPoint("TOPLEFT", 30, yOff)
    autoCollectCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatically collects the selected reward when the quest is turned in.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    autoCollectCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local rewardDropdown = CreateDropdown(panel, "PreyMateRewardDropdown", 110,
        REWARD_OPTIONS,
        function() return PM:GetProfile().autoCollectReward end,
        function(val) PM:GetProfile().autoCollectReward = val end
    )
    rewardDropdown:SetPoint("LEFT", autoCollectCB.Text, "RIGHT", -8, -2)
    PM.rewardDropdown = rewardDropdown
    yOff = yOff - 36

    -- Show minimap icon checkbox
    local minimapCB = CreateCheckbox(panel, "Show minimap icon", profile.showMinimapIcon, function(self, checked)
        local p = PM:GetProfile()
        p.showMinimapIcon = checked
        PM:UpdateMinimapIcon()
    end)
    minimapCB:SetPoint("TOPLEFT", 14, yOff)
    minimapCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggles the PreyMate minimap button.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    minimapCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.minimapCB = minimapCB
    yOff = yOff - 32

    -- Separator
    local hr = panel:CreateTexture(nil, "ARTWORK")
    hr:SetPoint("TOPLEFT", 16, yOff)
    hr:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hr:SetHeight(1)
    hr:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 12

    -- Debug checkbox
    local debugCB = CreateCheckbox(panel, "Enable debug logging", profile.debug, function(self, checked)
        local p = PM:GetProfile()
        p.debug = checked
        PM:ApplyProfile()
    end)
    debugCB:SetPoint("TOPLEFT", 14, yOff)
    debugCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Prints detailed addon activity to the chat window.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    debugCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    debugCB.Text:SetTextColor(0.5, 0.5, 0.5)

    -- Register with settings
    local category = Settings.RegisterCanvasLayoutCategory(panel, PM.ADDON_NAME)
    Settings.RegisterAddOnCategory(category)
    PM.settingsCategory = category
end


