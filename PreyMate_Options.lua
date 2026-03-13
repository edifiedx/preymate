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
-- Static Popup Dialogs
---------------------------------------------------------------------
StaticPopupDialogs["PREYMATE_CONFIRM_DELETE"] = {
    text = "Delete profile '%s'? This cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        PM:DeleteProfile(data)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["PREYMATE_CONFIRM_REMOVE_CHAR"] = {
    text = "Clear tracker data for '%s'? This removes their saved hunt counts. They will be re-added if they log in again.",
    button1 = "Clear",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if PreyMateDB.trackerCharacters then
            PreyMateDB.trackerCharacters[data] = nil
        end
        if PreyMateDB.trackerOrder then
            for i, key in ipairs(PreyMateDB.trackerOrder) do
                if key == data then
                    table.remove(PreyMateDB.trackerOrder, i)
                    break
                end
            end
        end
        if PM.trackerPanel then
            PM:BuildTrackerContent(PM.trackerPanel)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["PREYMATE_RENAME"] = {
    text = "Enter a new name for profile '%s':",
    button1 = "Rename",
    button2 = "Cancel",
    hasEditBox = 1,
    OnShow = function(self, data)
        self.editBox:SetText(data or "")
        self.editBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local newName = self.editBox:GetText()
        PM:RenameProfile(data, newName)
    end,
    EditBoxOnEnterPressed = function(self)
        local newName = self:GetText()
        PM:RenameProfile(self:GetParent().data, newName)
        StaticPopup_Hide("PREYMATE_RENAME")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["PREYMATE_CONFIRM_RESTORE"] = {
    text = "Reset all settings in '%s' to defaults? This cannot be undone.",
    button1 = "Restore",
    button2 = "Cancel",
    OnAccept = function(self, data)
        PM:RestoreDefaults()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["PREYMATE_POST_DELETE"] = {
    text = "Profile deleted. You've been moved to '%s'. Switch to a different profile?",
    button1 = "Switch Profile",
    button2 = "Keep",
    OnAccept = function()
        if PM.settingsCategory then
            Settings.OpenToCategory(PM.settingsCategory.ID)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

---------------------------------------------------------------------
-- Options refresh — called after any profile operation
---------------------------------------------------------------------
function PM:RefreshOptions()
    local profile, profileName = self:GetProfile()
    if self.profileDropdown then
        UIDropDownMenu_SetText(self.profileDropdown, profileName)
    end
    if self.profileDeleteBtn then
        if #self:GetProfileNames() <= 1 then
            self.profileDeleteBtn:Disable()
        else
            self.profileDeleteBtn:Enable()
        end
    end
    if self.autoAcceptCB   then self.autoAcceptCB:SetChecked(profile.autoAccept)      end
    if self.autoPayCB      then self.autoPayCB:SetChecked(profile.autoPayFee)         end
    if self.autoCompleteCB then self.autoCompleteCB:SetChecked(profile.autoComplete)  end
    if self.autoCollectCB  then self.autoCollectCB:SetChecked(profile.autoCollect)    end
    if self.minimapCB      then self.minimapCB:SetChecked(profile.showMinimapIcon)    end
    if self.debugCB        then self.debugCB:SetChecked(profile.debug)                end
    if self.levelDropdown      then self.levelDropdown:Refresh()      end
    if self.acceptModeDropdown then self.acceptModeDropdown:Refresh() end
    if self.rewardDropdown     then self.rewardDropdown:Refresh()     end
    if self.leftClickDropdown  then self.leftClickDropdown:Refresh()  end
    if self.showStatBalanceCB  then self.showStatBalanceCB:SetChecked(profile.showStatBalance)  end
    if self.showStatSessionCB  then self.showStatSessionCB:SetChecked(profile.showStatSession)  end
    if self.showStatPerHuntCB  then self.showStatPerHuntCB:SetChecked(profile.showStatPerHunt)  end
    if self.showStatPerHourCB  then self.showStatPerHourCB:SetChecked(profile.showStatPerHour)  end
    if self.showWeeklyTrackerCB then self.showWeeklyTrackerCB:SetChecked(profile.showWeeklyTracker) end
end

---------------------------------------------------------------------
-- Settings Panel
---------------------------------------------------------------------
function PM:InitSettings()
    local canvas = CreateFrame("Frame")
    canvas.name = PM.ADDON_NAME

    -- Wrap all content in a ScrollFrame so the panel can scroll
    local scrollFrame = CreateFrame("ScrollFrame", "PreyMateScrollFrame", canvas, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -20, 2)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(680, 1)  -- height is set after all content is laid out
    scrollFrame:SetScrollChild(scrollChild)
    -- Keep scroll child width in sync when the panel is resized
    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    -- Shadow 'panel' so every piece of content below is automatically
    -- parented to and laid out within the scrollable content area
    local panel = scrollChild

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
    -- Profile Section
    -----------------------------------------------------------------
    local profileHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profileHeader:SetPoint("TOPLEFT", 16, yOff)
    profileHeader:SetText("Profile")
    yOff = yOff - 16

    local hrProfileTop = panel:CreateTexture(nil, "ARTWORK")
    hrProfileTop:SetPoint("TOPLEFT", 16, yOff)
    hrProfileTop:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrProfileTop:SetHeight(1)
    hrProfileTop:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 14

    local profileDropdown = CreateFrame("Frame", "PreyMateProfileDropdown", panel, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(profileDropdown, 150)
    UIDropDownMenu_Initialize(profileDropdown, function()
        local _, currentName = PM:GetProfile()
        for _, pName in ipairs(PM:GetProfileNames()) do
            local n = pName
            local info = UIDropDownMenu_CreateInfo()
            info.text    = n
            info.value   = n
            info.checked = (n == currentName)
            info.func    = function()
                PM:SwitchProfile(n)
                UIDropDownMenu_SetText(profileDropdown, n)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    profileDropdown:SetPoint("TOPLEFT", 10, yOff)
    profileDropdown:EnableMouse(true)
    profileDropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("The active settings profile for this character.\nMultiple characters can share a profile — changes apply to all of them.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    profileDropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.profileDropdown = profileDropdown

    local cloneBtn = CreateButton(panel, "Clone", 60, function()
        PM:CloneProfile()
    end)
    cloneBtn:SetPoint("LEFT", profileDropdown, "RIGHT", -10, 2)
    cloneBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Copy the current profile. The clone is named after your character and realm by default.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    cloneBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local renameBtn = CreateButton(panel, "Rename", 65, function()
        local _, profileName = PM:GetProfile()
        StaticPopup_Show("PREYMATE_RENAME", profileName, nil, profileName)
    end)
    renameBtn:SetPoint("LEFT", cloneBtn, "RIGHT", 4, 0)
    renameBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Give the current profile a new name. All characters using this profile will see the new name.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    renameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local deleteBtn = CreateButton(panel, "Delete", 60, function()
        local _, profileName = PM:GetProfile()
        StaticPopup_Show("PREYMATE_CONFIRM_DELETE", profileName, nil, profileName)
    end)
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 4, 0)
    deleteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete the current profile. Characters assigned to it will be moved to the next available profile. Disabled when only one profile exists.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.profileDeleteBtn = deleteBtn
    if #PM:GetProfileNames() <= 1 then deleteBtn:Disable() end

    local restoreBtn = CreateButton(panel, "Reset", 60, function()
        local _, profileName = PM:GetProfile()
        StaticPopup_Show("PREYMATE_CONFIRM_RESTORE", profileName, nil, profileName)
    end)
    restoreBtn:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    restoreBtn:SetPoint("TOP", deleteBtn, "TOP", 0, 0)
    restoreBtn:SetAlpha(0.5)
    restoreBtn:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset all settings in the current profile to their default values.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    restoreBtn:SetScript("OnLeave", function(self)
        self:SetAlpha(0.5)
        GameTooltip:Hide()
    end)

    local _, initProfileName = PM:GetProfile()
    UIDropDownMenu_SetText(profileDropdown, initProfileName)
    yOff = yOff - 36

    local hrProfileBottom = panel:CreateTexture(nil, "ARTWORK")
    hrProfileBottom:SetPoint("TOPLEFT", 16, yOff)
    hrProfileBottom:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrProfileBottom:SetHeight(1)
    hrProfileBottom:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 16

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
    PM.autoAcceptCB = autoAcceptCB
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
    PM.autoPayCB = autoPayCB
    yOff = yOff - 32

    local hrAcceptBottom = panel:CreateTexture(nil, "ARTWORK")
    hrAcceptBottom:SetPoint("TOPLEFT", 16, yOff)
    hrAcceptBottom:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrAcceptBottom:SetHeight(1)
    hrAcceptBottom:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 16

    local autoCompleteHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoCompleteHeader:SetPoint("TOPLEFT", 16, yOff)
    autoCompleteHeader:SetText("Auto Complete")
    yOff = yOff - 24

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
    PM.autoCompleteCB = autoCompleteCB
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
    PM.autoCollectCB = autoCollectCB

    local rewardDropdown = CreateDropdown(panel, "PreyMateRewardDropdown", 110,
        REWARD_OPTIONS,
        function() return PM:GetProfile().autoCollectReward end,
        function(val) PM:GetProfile().autoCollectReward = val end
    )
    rewardDropdown:SetPoint("LEFT", autoCollectCB.Text, "RIGHT", -8, -2)
    PM.rewardDropdown = rewardDropdown
    yOff = yOff - 36

    local hrMinimapTop = panel:CreateTexture(nil, "ARTWORK")
    hrMinimapTop:SetPoint("TOPLEFT", 16, yOff)
    hrMinimapTop:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrMinimapTop:SetHeight(1)
    hrMinimapTop:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 14

    local minimapHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    minimapHeader:SetPoint("TOPLEFT", 16, yOff)
    minimapHeader:SetText("Minimap")
    yOff = yOff - 24

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
    yOff = yOff - 28

    -- Left-click action label + dropdown (inline, indented under minimap)
    local leftClickLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    leftClickLabel:SetPoint("TOPLEFT", 34, yOff)
    leftClickLabel:SetText("Left click:")

    local leftClickOptions = {
        { text = "Track Hunt",    value = PM.LCLICK_TRACK    },
        { text = "Open Settings", value = PM.LCLICK_SETTINGS },
        { text = "Print Stats",   value = PM.LCLICK_STATS    },
    }
    local leftClickDropdown = CreateDropdown(panel, "PreyMateLeftClickDropdown", 110,
        leftClickOptions,
        function() return PM:GetProfile().leftClickAction end,
        function(val) PM:GetProfile().leftClickAction = val end
    )
    leftClickDropdown:SetPoint("LEFT", leftClickLabel, "RIGHT", -10, -2)
    leftClickDropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Choose what left-clicking the minimap button does.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    leftClickDropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.leftClickDropdown = leftClickDropdown
    yOff = yOff - 32

    local hrStatsTop = panel:CreateTexture(nil, "ARTWORK")
    hrStatsTop:SetPoint("TOPLEFT", 16, yOff)
    hrStatsTop:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrStatsTop:SetHeight(1)
    hrStatsTop:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOff = yOff - 14

    local statsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statsHeader:SetPoint("TOPLEFT", 16, yOff)
    statsHeader:SetText("Stats Tracking")
    yOff = yOff - 24

    local showStatBalanceCB = CreateCheckbox(panel, "Show current Anguish balance", profile.showStatBalance, function(self, checked)
        PM:GetProfile().showStatBalance = checked
    end)
    showStatBalanceCB:SetPoint("TOPLEFT", 14, yOff)
    showStatBalanceCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show your current Anguish quantity in the minimap tooltip.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    showStatBalanceCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.showStatBalanceCB = showStatBalanceCB
    yOff = yOff - 24

    local showStatSessionCB = CreateCheckbox(panel, "Show session delta", profile.showStatSession, function(self, checked)
        PM:GetProfile().showStatSession = checked
    end)
    showStatSessionCB:SetPoint("TOPLEFT", 14, yOff)
    showStatSessionCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show total Anguish gained or lost this session.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    showStatSessionCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.showStatSessionCB = showStatSessionCB
    yOff = yOff - 24

    local showStatPerHuntCB = CreateCheckbox(panel, "Show per-hunt average", profile.showStatPerHunt, function(self, checked)
        PM:GetProfile().showStatPerHunt = checked
    end)
    showStatPerHuntCB:SetPoint("TOPLEFT", 14, yOff)
    showStatPerHuntCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show average Anguish delta per completed hunt this session.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    showStatPerHuntCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.showStatPerHuntCB = showStatPerHuntCB
    yOff = yOff - 24

    local showStatPerHourCB = CreateCheckbox(panel, "Show per-hour rate", profile.showStatPerHour, function(self, checked)
        PM:GetProfile().showStatPerHour = checked
    end)
    showStatPerHourCB:SetPoint("TOPLEFT", 14, yOff)
    showStatPerHourCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show Anguish rate per hour. Requires at least 1 minute of session time.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    showStatPerHourCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.showStatPerHourCB = showStatPerHourCB
    yOff = yOff - 24

    local showWeeklyTrackerCB = CreateCheckbox(panel, "Show weekly hunt tracker", profile.showWeeklyTracker, function(self, checked)
        PM:GetProfile().showWeeklyTracker = checked
    end)
    showWeeklyTrackerCB:SetPoint("TOPLEFT", 14, yOff)
    showWeeklyTrackerCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show warband weekly hunt progress and per-character breakdown in the minimap tooltip.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    showWeeklyTrackerCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PM.showWeeklyTrackerCB = showWeeklyTrackerCB
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
    PM.debugCB = debugCB

    -- Size the scroll child to exactly contain all laid-out content
    scrollChild:SetHeight(-yOff + 32)

    -- Register the outer canvas (not the scroll child) with the Settings API
    local category = Settings.RegisterCanvasLayoutCategory(canvas, PM.ADDON_NAME)
    Settings.RegisterAddOnCategory(category)
    PM.settingsCategory = category

    -- Build the Rewards Tracker sub-page
    PM:InitTrackerSettings(category)
end

---------------------------------------------------------------------
-- Rewards Tracker Sub-Page
---------------------------------------------------------------------
function PM:InitTrackerSettings(parentCategory)
    local canvas = CreateFrame("Frame")
    canvas.name = "Rewards Tracker"

    local scrollFrame = CreateFrame("ScrollFrame", "PreyMateTrackerScrollFrame", canvas, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -20, 2)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(680, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    local panel = scrollChild
    PM.trackerPanel = panel
    PM.trackerScrollChild = scrollChild

    self:BuildTrackerContent(panel)

    local subCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, canvas, "Rewards Tracker")
    PM.trackerCategory = subCategory
end

local TRACKER_ROW_HEIGHT = 28

-- Helper: update column header checkbox to show mixed state (grey check)
-- when the default is off but at least one character has the column enabled
local function UpdateColumnHeaderState(cb, profileKey, charDataKey)
    local profile = PM:GetProfile()
    local defaultOn = profile[profileKey]
    if defaultOn then
        cb:SetChecked(true)
        cb:GetCheckedTexture():SetDesaturated(false)
        cb:GetCheckedTexture():SetAlpha(1)
        return
    end
    -- Default is off — check if any character has it individually enabled
    local anyOn = false
    if PreyMateDB.trackerCharacters then
        for _, data in pairs(PreyMateDB.trackerCharacters) do
            if data[charDataKey] then anyOn = true; break end
        end
    end
    if anyOn then
        -- Mixed state: show a desaturated (grey) check
        cb:SetChecked(true)
        cb:GetCheckedTexture():SetDesaturated(true)
        cb:GetCheckedTexture():SetAlpha(0.5)
    else
        cb:SetChecked(false)
        cb:GetCheckedTexture():SetDesaturated(false)
        cb:GetCheckedTexture():SetAlpha(1)
    end
end

function PM:BuildTrackerContent(panel)
    -- Clear previous content if rebuilding
    if PM.trackerRowFrames then
        for _, rf in ipairs(PM.trackerRowFrames) do
            rf:ClearAllPoints()
            rf:Hide()
            rf:SetParent(nil)
        end
    end
    if PM.trackerRows then
        for _, row in ipairs(PM.trackerRows) do
            for _, widget in ipairs(row.widgets) do
                widget:Hide()
                widget:SetParent(nil)
            end
        end
    end
    if PM.trackerStatic then
        for _, w in ipairs(PM.trackerStatic) do
            w:Hide()
            w:SetParent(nil)
        end
    end
    PM.trackerRows = {}
    PM.trackerRowFrames = {}
    PM.trackerStatic = {}
    local statics = PM.trackerStatic

    local yOff = -16

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, yOff)
    title:SetText("|cffcc3333Prey|rMate — Rewards Tracker")
    statics[#statics + 1] = title
    yOff = yOff - 24

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 16, yOff)
    desc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(
        "Manage which characters and difficulties appear in the minimap tooltip's weekly hunt tracker. " ..
        "Characters are automatically added when they log in. " ..
        "Use the column headers to toggle a difficulty on or off for all characters (also sets the default for new characters). " ..
        "Drag the handle on the left to reorder characters."
    )
    statics[#statics + 1] = desc
    yOff = yOff - 52

    local hrTop = panel:CreateTexture(nil, "ARTWORK")
    hrTop:SetPoint("TOPLEFT", 16, yOff)
    hrTop:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hrTop:SetHeight(1)
    hrTop:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    statics[#statics + 1] = hrTop
    yOff = yOff - 18

    -- Column header: Show
    local colShow = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colShow:SetPoint("TOPLEFT", 30, yOff)
    colShow:SetText("Show")
    statics[#statics + 1] = colShow

    -- Column header: Character
    local colName = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colName:SetPoint("TOPLEFT", 72, yOff)
    colName:SetText("Character")
    statics[#statics + 1] = colName

    -- Column header checkboxes — toggle entire column + set new-char default
    local HEADER_TOOLTIP = "Toggle this difficulty for all characters.\nNew characters will inherit this setting.\nYou can override individual characters below."

    local colNCB = CreateCheckbox(panel, "N", true, function(self, checked)
        if PreyMateDB.trackerCharacters then
            for _, data in pairs(PreyMateDB.trackerCharacters) do
                data.showNormal = checked
            end
        end
        PM:GetProfile().trackerShowNormal = checked
        PM:BuildTrackerContent(panel)
    end)
    colNCB:SetPoint("TOPLEFT", 240, yOff + 6)
    colNCB.Text:SetFontObject("GameFontHighlightSmall")
    colNCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(HEADER_TOOLTIP, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    colNCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    statics[#statics + 1] = colNCB

    local colHCB = CreateCheckbox(panel, "H", true, function(self, checked)
        if PreyMateDB.trackerCharacters then
            for _, data in pairs(PreyMateDB.trackerCharacters) do
                data.showHard = checked
            end
        end
        PM:GetProfile().trackerShowHard = checked
        PM:BuildTrackerContent(panel)
    end)
    colHCB:SetPoint("TOPLEFT", 290, yOff + 6)
    colHCB.Text:SetFontObject("GameFontHighlightSmall")
    colHCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(HEADER_TOOLTIP, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    colHCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    statics[#statics + 1] = colHCB

    local colNMCB = CreateCheckbox(panel, "NM", true, function(self, checked)
        if PreyMateDB.trackerCharacters then
            for _, data in pairs(PreyMateDB.trackerCharacters) do
                data.showNightmare = checked
            end
        end
        PM:GetProfile().trackerShowNightmare = checked
        PM:BuildTrackerContent(panel)
    end)
    colNMCB:SetPoint("TOPLEFT", 340, yOff + 6)
    colNMCB.Text:SetFontObject("GameFontHighlightSmall")
    colNMCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(HEADER_TOOLTIP, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    colNMCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    statics[#statics + 1] = colNMCB

    -- Set column header states (checked / unchecked / grey-mixed)
    UpdateColumnHeaderState(colNCB, "trackerShowNormal", "showNormal")
    UpdateColumnHeaderState(colHCB, "trackerShowHard", "showHard")
    UpdateColumnHeaderState(colNMCB, "trackerShowNightmare", "showNightmare")

    yOff = yOff - 22

    -- Drag indicator (created once, reused)
    if not PM.dragIndicator then
        local indicator = CreateFrame("Frame", nil, panel)
        indicator:SetHeight(2)
        indicator:SetFrameStrata("TOOLTIP")
        local tex = indicator:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetColorTexture(1, 0.8, 0, 0.9)
        indicator:Hide()
        PM.dragIndicator = indicator
    else
        PM.dragIndicator:SetParent(panel)
    end

    -- Track where character rows begin for drag calculations
    local charRowStartY = yOff

    -- Get ordered character list
    local orderedKeys = PM:GetTrackerOrder()

    -- Store header CBs for mixed-state refresh from per-char toggles
    PM.trackerColNCB = colNCB
    PM.trackerColHCB = colHCB
    PM.trackerColNMCB = colNMCB

    for idx, charKey in ipairs(orderedKeys) do
        local data = PreyMateDB.trackerCharacters[charKey]
        local row = { widgets = {} }
        local key = charKey

        -- Container frame for this row
        local rowFrame = CreateFrame("Frame", nil, panel)
        rowFrame:SetSize(480, TRACKER_ROW_HEIGHT)
        rowFrame:SetPoint("TOPLEFT", 0, yOff)
        rowFrame.charKey = charKey
        rowFrame.orderIndex = idx

        -- Drag handle (three horizontal lines)
        local handle = CreateFrame("Frame", nil, rowFrame)
        handle:SetSize(14, TRACKER_ROW_HEIGHT)
        handle:SetPoint("LEFT", 2, 0)
        handle:EnableMouse(true)
        handle:RegisterForDrag("LeftButton")
        handle.lines = {}
        for i = 0, 2 do
            local line = handle:CreateTexture(nil, "ARTWORK")
            line:SetSize(8, 1)
            line:SetPoint("TOP", 0, -9 - (i * 4))
            line:SetColorTexture(0.5, 0.5, 0.5, 0.6)
            handle.lines[i + 1] = line
        end

        handle:SetScript("OnEnter", function(self)
            if PM.isDragging then return end
            for _, l in ipairs(self.lines) do l:SetColorTexture(0.9, 0.9, 0.9, 1) end
        end)
        handle:SetScript("OnLeave", function(self)
            if PM.isDragging then return end
            for _, l in ipairs(self.lines) do l:SetColorTexture(0.5, 0.5, 0.5, 0.6) end
        end)

        handle:SetScript("OnDragStart", function(self)
            local rf = self:GetParent()
            rf:SetAlpha(0.3)
            -- Reset this handle's highlight immediately
            for _, l in ipairs(self.lines) do l:SetColorTexture(0.5, 0.5, 0.5, 0.6) end
            PM.isDragging = true
            PM.dragSourceIndex = rf.orderIndex
            PM.dragSourceFrame = rf
            PM.dragCharRowStartY = charRowStartY
            PM.dragPanel = panel

            if not PM.dragTracker then
                PM.dragTracker = CreateFrame("Frame")
            end
            PM.dragTracker:SetScript("OnUpdate", function()
                if not PM.isDragging then return end
                local _, cursorY = GetCursorPosition()
                local scale = panel:GetEffectiveScale()
                cursorY = cursorY / scale
                local panelTop = panel:GetTop() or 0
                local relY = cursorY - panelTop  -- negative, same coord system as yOff
                local distFromStart = PM.dragCharRowStartY - relY
                local numRows = #PM.trackerRowFrames

                -- Determine which gap the cursor is nearest
                local gap = math.floor(distFromStart / TRACKER_ROW_HEIGHT + 0.5) + 1
                gap = math.max(1, math.min(gap, numRows + 1))

                -- Skip indicator if drop would be a no-op
                local src = PM.dragSourceIndex
                if gap == src or gap == src + 1 then
                    PM.dragIndicator:Hide()
                    PM.dragTargetGap = nil
                else
                    PM.dragTargetGap = gap
                    local indicatorY = PM.dragCharRowStartY - (gap - 1) * TRACKER_ROW_HEIGHT
                    PM.dragIndicator:ClearAllPoints()
                    PM.dragIndicator:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, indicatorY)
                    PM.dragIndicator:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
                    PM.dragIndicator:Show()
                end
            end)
            PM.dragTracker:Show()
        end)

        handle:SetScript("OnDragStop", function(self)
            if PM.dragSourceFrame then
                PM.dragSourceFrame:SetAlpha(1)
            end
            PM.isDragging = false
            PM.dragIndicator:Hide()
            if PM.dragTracker then
                PM.dragTracker:SetScript("OnUpdate", nil)
                PM.dragTracker:Hide()
            end

            -- Reorder if the drop position changed
            local fromIdx = PM.dragSourceIndex
            local gap = PM.dragTargetGap
            if fromIdx and gap then
                local toIdx = gap
                if toIdx > fromIdx then toIdx = toIdx - 1 end
                if fromIdx ~= toIdx then
                    local order = PreyMateDB.trackerOrder
                    local moving = table.remove(order, fromIdx)
                    table.insert(order, toIdx, moving)
                end
            end
            PM.dragSourceIndex = nil
            PM.dragSourceFrame = nil
            PM.dragTargetGap = nil
            PM:BuildTrackerContent(panel)
        end)

        -- Show checkbox
        local showCB = CreateCheckbox(rowFrame, "", data.showInTooltip ~= false, function(self, checked)
            PreyMateDB.trackerCharacters[key].showInTooltip = checked
        end)
        showCB:SetPoint("TOPLEFT", 30, 0)
        row.widgets[#row.widgets + 1] = showCB

        -- Character name
        local nameLabel = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        nameLabel:SetPoint("TOPLEFT", 72, -5)
        nameLabel:SetText(charKey)
        row.widgets[#row.widgets + 1] = nameLabel

        -- N checkbox
        local nCB = CreateCheckbox(rowFrame, "", data.showNormal ~= false, function(self, checked)
            PreyMateDB.trackerCharacters[key].showNormal = checked
            UpdateColumnHeaderState(PM.trackerColNCB, "trackerShowNormal", "showNormal")
        end)
        nCB:SetPoint("TOPLEFT", 247, 0)
        row.widgets[#row.widgets + 1] = nCB

        -- H checkbox
        local hCB = CreateCheckbox(rowFrame, "", data.showHard ~= false, function(self, checked)
            PreyMateDB.trackerCharacters[key].showHard = checked
            UpdateColumnHeaderState(PM.trackerColHCB, "trackerShowHard", "showHard")
        end)
        hCB:SetPoint("TOPLEFT", 297, 0)
        row.widgets[#row.widgets + 1] = hCB

        -- NM checkbox
        local nmCB = CreateCheckbox(rowFrame, "", data.showNightmare ~= false, function(self, checked)
            PreyMateDB.trackerCharacters[key].showNightmare = checked
            UpdateColumnHeaderState(PM.trackerColNMCB, "trackerShowNightmare", "showNightmare")
        end)
        nmCB:SetPoint("TOPLEFT", 347, 0)
        row.widgets[#row.widgets + 1] = nmCB

        -- Clear button (far right)
        local removeBtn = CreateButton(rowFrame, "Clear", 44, function()
            StaticPopup_Show("PREYMATE_CONFIRM_REMOVE_CHAR", charKey, nil, key)
        end)
        removeBtn:SetPoint("TOPLEFT", 580, -2)
        removeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Clear tracker data for this character.\nThey will be re-added on next login.", nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.widgets[#row.widgets + 1] = removeBtn

        PM.trackerRows[#PM.trackerRows + 1] = row
        PM.trackerRowFrames[#PM.trackerRowFrames + 1] = rowFrame
        yOff = yOff - TRACKER_ROW_HEIGHT
    end

    if #orderedKeys == 0 then
        local noChars = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        noChars:SetPoint("TOPLEFT", 16, yOff)
        noChars:SetText("No characters registered yet. Log in on a character to add it.")
        statics[#statics + 1] = noChars
        yOff = yOff - 24
    end

    panel:SetHeight(-yOff + 32)
end