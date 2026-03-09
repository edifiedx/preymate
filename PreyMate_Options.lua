-- PreyMate_Options.lua
local PM = PreyMate

local PREY_LEVELS = { "Normal", "Hard", "Nightmare" }

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
    yOff = yOff - 24

    local profile = PM:GetProfile()

    -- Auto-accept checkbox
    local autoAcceptCB = CreateCheckbox(panel, "Auto-accept Prey quest", profile.autoAccept, function(self, checked)
        local p = PM:GetProfile()
        p.autoAccept = checked
    end)
    autoAcceptCB:SetPoint("TOPLEFT", 14, yOff)
    yOff = yOff - 28

    -- Prey level dropdown
    local levelLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    levelLabel:SetPoint("TOPLEFT", 18, yOff)
    levelLabel:SetText("Prey Level:")

    local levelOptions = {}
    for i, name in ipairs(PREY_LEVELS) do
        levelOptions[i] = { text = name, value = i }
    end

    local levelDropdown = CreateDropdown(panel, "PreyMateLevelDropdown", 120,
        levelOptions,
        function() return PM:GetProfile().preyLevel end,
        function(val) PM:GetProfile().preyLevel = val end
    )
    levelDropdown:SetPoint("LEFT", levelLabel, "RIGHT", -8, -2)
    PM.levelDropdown = levelDropdown
    yOff = yOff - 36

    -- Auto-pay fee checkbox
    local autoPayCB = CreateCheckbox(panel, "Auto-pay hunt fee", profile.autoPayFee, function(self, checked)
        local p = PM:GetProfile()
        p.autoPayFee = checked
    end)
    autoPayCB:SetPoint("TOPLEFT", 14, yOff)
    yOff = yOff - 28

    -- Debug checkbox
    local debugCB = CreateCheckbox(panel, "Enable debug logging", profile.debug, function(self, checked)
        local p = PM:GetProfile()
        p.debug = checked
        PM:ApplyProfile()
    end)
    debugCB:SetPoint("TOPLEFT", 14, yOff)
    debugCB.Text:SetTextColor(0.5, 0.5, 0.5)

    -- Register with settings
    local category = Settings.RegisterCanvasLayoutCategory(panel, PM.ADDON_NAME)
    category.ID = PM.ADDON_NAME
    Settings.RegisterAddOnCategory(category)
end


