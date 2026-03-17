---------------------------------------------------------------------
-- PreyMate_Tracker.lua — Weekly rewards tracker
---------------------------------------------------------------------
local PM = PreyMate

local PREY_QUEST_LINE_ID = 5945

local TRACKER_SCAN_DELAY = 2     -- seconds before first attempt
local MAX_SCAN_RETRIES   = 4     -- retry up to this many times

local BONUS_THRESHOLD      = 4   -- warband hunts needed for Journey Bonus
local MAX_HUNTS_PER_DIFFICULTY = 4
local GEAR_CAP             = 2   -- gear only drops from the first 2
local TRACKER_ROW_HEIGHT   = 28

local DEBUG = false

local function log(...)
    if PM.debug then print(PM.PREFIX, ...) end
end

---------------------------------------------------------------------
-- Scan helpers
---------------------------------------------------------------------
local function ParseDifficulty(title)
    return title:match("%((%a+)%)$") or "Unknown"
end

function PM:ScanWarbandHunts()
    local quests = C_QuestLine.GetQuestLineQuests(PREY_QUEST_LINE_ID)
    local counts = { Normal = 0, Hard = 0, Nightmare = 0, total = 0 }
    for _, qid in ipairs(quests) do
        if C_QuestLog.IsQuestFlaggedCompletedOnAccount(qid) then
            local title = C_QuestLog.GetTitleForQuestID(qid) or ""
            local diff = ParseDifficulty(title)
            counts[diff] = (counts[diff] or 0) + 1
            counts.total = counts.total + 1
        end
    end
    return counts
end

function PM:ScanCharacterHunts()
    local quests = C_QuestLine.GetQuestLineQuests(PREY_QUEST_LINE_ID)
    if #quests == 0 then return nil end  -- quest line data not loaded yet
    local counts = { Normal = 0, Hard = 0, Nightmare = 0, total = 0 }
    for _, qid in ipairs(quests) do
        if C_QuestLog.IsQuestFlaggedCompleted(qid) then
            local title = C_QuestLog.GetTitleForQuestID(qid) or ""
            local diff = ParseDifficulty(title)
            counts[diff] = (counts[diff] or 0) + 1
            counts.total = counts.total + 1
        end
    end
    return counts
end

function PM:DebugWeeklyHunts()
    local quests = C_QuestLine.GetQuestLineQuests(PREY_QUEST_LINE_ID)
    local charName = UnitName("player")
    local warbandList, charList = {}, {}

    for _, qid in ipairs(quests) do
        local title = C_QuestLog.GetTitleForQuestID(qid) or "?"
        local acct = C_QuestLog.IsQuestFlaggedCompletedOnAccount(qid)
        local char = C_QuestLog.IsQuestFlaggedCompleted(qid)
        if acct then
            warbandList[#warbandList + 1] = { qid = qid, title = title, charToo = char }
        end
        if char and not acct then
            charList[#charList + 1] = { qid = qid, title = title }
        end
    end

    print(PM.PREFIX, "|cffffff00Weekly Hunt Debug|r — " .. charName)
    print(PM.PREFIX, "Total quests in line:", #quests)
    print(PM.PREFIX, "")
    print(PM.PREFIX, "|cff00ff00Warband-flagged:|r", #warbandList)
    for _, e in ipairs(warbandList) do
        local tag = e.charToo and " |cff888888(this char too)|r" or " |cffff8800(other char)|r"
        print(PM.PREFIX, "  " .. e.qid .. " " .. e.title .. tag)
    end

    if #charList > 0 then
        print(PM.PREFIX, "")
        print(PM.PREFIX, "|cffff0000Char-only (NOT warband-flagged):|r", #charList)
        for _, e in ipairs(charList) do
            print(PM.PREFIX, "  " .. e.qid .. " " .. e.title)
        end
    end
end

---------------------------------------------------------------------
-- Tracker order management
---------------------------------------------------------------------
function PM:GetTrackerOrder()
    if not PreyMateDB.trackerOrder then PreyMateDB.trackerOrder = {} end
    local chars = PreyMateDB.trackerCharacters or {}
    local inOrder = {}
    for _, key in ipairs(PreyMateDB.trackerOrder) do
        inOrder[key] = true
    end
    for key in pairs(chars) do
        if not inOrder[key] then
            PreyMateDB.trackerOrder[#PreyMateDB.trackerOrder + 1] = key
        end
    end
    local cleaned = {}
    for _, key in ipairs(PreyMateDB.trackerOrder) do
        if chars[key] then
            cleaned[#cleaned + 1] = key
        end
    end
    PreyMateDB.trackerOrder = cleaned
    return cleaned
end

---------------------------------------------------------------------
-- Weekly reset detection
---------------------------------------------------------------------
local function CheckWeeklyReset()
    local now = GetServerTime()
    local secsUntil = C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secsUntil or secsUntil == 0 then
        log("GetSecondsUntilWeeklyReset not available yet — skipping reset check")
        return
    end
    local nextReset = now + secsUntil

    local shouldWipe = false
    if not PreyMateDB.trackerResetTime then
        -- No stamp yet (upgrade from older version) — assume stale
        shouldWipe = true
        log("No tracker reset stamp found — clearing stale scan data")
    elseif now >= PreyMateDB.trackerResetTime then
        -- A weekly reset has occurred
        shouldWipe = true
        log("Weekly reset detected — clearing all tracker scan data")
    end

    if shouldWipe and PreyMateDB.trackerCharacters then
        for _, data in pairs(PreyMateDB.trackerCharacters) do
            data.lastScan = nil
        end
    end

    PreyMateDB.trackerResetTime = nextReset
end

---------------------------------------------------------------------
-- Character registration (called from PLAYER_ENTERING_WORLD)
---------------------------------------------------------------------
function PM:RegisterTrackerCharacter()
    CheckWeeklyReset()

    local trackerKey = self:GetCharKey()
    if not PreyMateDB.trackerCharacters[trackerKey] then
        local profile = self:GetProfile()
        PreyMateDB.trackerCharacters[trackerKey] = {
            showInTooltip = true,
            showNormal    = profile.trackerShowNormal,
            showHard      = profile.trackerShowHard,
            showNightmare = profile.trackerShowNightmare,
        }
        local found = false
        for _, k in ipairs(PreyMateDB.trackerOrder) do
            if k == trackerKey then found = true; break end
        end
        if not found then
            PreyMateDB.trackerOrder[#PreyMateDB.trackerOrder + 1] = trackerKey
        end
    end
    -- Deferred initial scan — quest line data is often not available yet
    local function initialTrackerScan(attempt)
        local tk = self:GetCharKey()
        if not PreyMateDB.trackerCharacters or not PreyMateDB.trackerCharacters[tk] then return end
        local result = self:ScanCharacterHunts()
        if result then
            PreyMateDB.trackerCharacters[tk].lastScan = result
            log("Initial tracker scan complete:", result.total, "hunts")
        elseif attempt < MAX_SCAN_RETRIES then
            log("Tracker scan deferred — quest line data not loaded (retry", attempt + 1 .. ")")
            C_Timer.After(attempt + 1, function() initialTrackerScan(attempt + 1) end)
        else
            log("Tracker scan gave up after", MAX_SCAN_RETRIES, "retries")
        end
    end
    C_Timer.After(TRACKER_SCAN_DELAY, function() initialTrackerScan(0) end)
end

---------------------------------------------------------------------
-- Refresh scan (called from QUEST_REMOVED and QUEST_LOG_UPDATE)
---------------------------------------------------------------------
function PM:RefreshTrackerScan()
    local tk = self:GetCharKey()
    if PreyMateDB.trackerCharacters and PreyMateDB.trackerCharacters[tk] then
        local result = self:ScanCharacterHunts()
        if result then
            PreyMateDB.trackerCharacters[tk].lastScan = result
            log("Weekly tracker scan refreshed")
        end
    end
end

---------------------------------------------------------------------
-- Tooltip integration (called from minimap OnTooltipShow)
---------------------------------------------------------------------
function PM:AddTrackerTooltip(tooltip, profile)
    if not profile.showWeeklyTracker then return end

    tooltip:AddLine(" ")
    local warband = self:ScanWarbandHunts()
    local bonusDone = math.min(warband.total, BONUS_THRESHOLD)
    local bonusR, bonusG, bonusB = 1, 0.85, 0.1
    if bonusDone >= BONUS_THRESHOLD then bonusR, bonusG, bonusB = 0.2, 1, 0.2 end
    tooltip:AddDoubleLine("Journey Bonus:", bonusDone .. "/" .. BONUS_THRESHOLD, 0.7, 0.7, 0.7, bonusR, bonusG, bonusB)

    if PreyMateDB.trackerCharacters then
        local orderedKeys = self:GetTrackerOrder()
        local hasAnyChar = false
        for _, charKey in ipairs(orderedKeys) do
            local data = PreyMateDB.trackerCharacters[charKey]
            if data.showInTooltip then hasAnyChar = true; break end
        end
        if hasAnyChar then
            tooltip:AddLine("Item Rewards:", 0.7, 0.7, 0.7)
        end
        local EMPTY_SCAN = { Normal = 0, Hard = 0, Nightmare = 0, total = 0 }
        for _, charKey in ipairs(orderedKeys) do
            local data = PreyMateDB.trackerCharacters[charKey]
            if data.showInTooltip then
                local sc = data.lastScan or EMPTY_SCAN
                local charName = charKey:match("^(.+) %- ") or charKey
                local COL_PAD = "        "
                local function fmtCol(label, count)
                    local v = math.min(count, MAX_HUNTS_PER_DIFFICULTY)
                    local cr, cg, cb = 1, 0.35, 0.35        -- 0: red
                    if v > GEAR_CAP then cr, cg, cb = 0.4, 0.8, 1       -- 3-4: cyan (past gear cap)
                    elseif v == GEAR_CAP then cr, cg, cb = 0.2, 1, 0.2  -- 2: green (gear cap reached)
                    elseif v == 1 then cr, cg, cb = 1, 0.65, 0 end      -- 1: orange
                    return string.format("|cff%02x%02x%02x%s:%d|r", cr * 255, cg * 255, cb * 255, label, v)
                end
                local slots = {}
                slots[#slots + 1] = (data.showNormal ~= false) and fmtCol("N", sc.Normal or 0) or COL_PAD
                slots[#slots + 1] = (data.showHard ~= false) and fmtCol("H", sc.Hard or 0) or COL_PAD
                slots[#slots + 1] = (data.showNightmare ~= false) and fmtCol("NM", sc.Nightmare or 0) or COL_PAD
                local hasAny = (data.showNormal ~= false) or (data.showHard ~= false) or (data.showNightmare ~= false)
                if hasAny then
                    tooltip:AddDoubleLine("  " .. charName, table.concat(slots, "  "), 0.5, 0.5, 0.5, 1, 1, 1)
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- Settings sub-page
---------------------------------------------------------------------
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

local function UpdateColumnHeaderState(cb, profileKey, charDataKey)
    local profile = PM:GetProfile()
    local defaultOn = profile[profileKey]
    if defaultOn then
        cb:SetChecked(true)
        cb:GetCheckedTexture():SetDesaturated(false)
        cb:GetCheckedTexture():SetAlpha(1)
        return
    end
    local anyOn = false
    if PreyMateDB.trackerCharacters then
        for _, data in pairs(PreyMateDB.trackerCharacters) do
            if data[charDataKey] then anyOn = true; break end
        end
    end
    if anyOn then
        cb:SetChecked(true)
        cb:GetCheckedTexture():SetDesaturated(true)
        cb:GetCheckedTexture():SetAlpha(0.5)
    else
        cb:SetChecked(false)
        cb:GetCheckedTexture():SetDesaturated(false)
        cb:GetCheckedTexture():SetAlpha(1)
    end
end

---------------------------------------------------------------------
-- UI helpers (local to this file)
---------------------------------------------------------------------
local checkCounter = 1000  -- offset to avoid collisions with Options checkCounter

local function CreateCheckbox(parent, label, checked, onClick)
    local cb = CreateFrame("CheckButton", "PreyMateTrackerOpt" .. checkCounter, parent, "InterfaceOptionsCheckButtonTemplate")
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

local function CreateButton(parent, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

---------------------------------------------------------------------
-- Sub-page init
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

    -- Column headers
    local colShow = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colShow:SetPoint("TOPLEFT", 30, yOff)
    colShow:SetText("Show")
    statics[#statics + 1] = colShow

    local colName = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colName:SetPoint("TOPLEFT", 72, yOff)
    colName:SetText("Character")
    statics[#statics + 1] = colName

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

    local charRowStartY = yOff
    local orderedKeys = PM:GetTrackerOrder()

    PM.trackerColNCB = colNCB
    PM.trackerColHCB = colHCB
    PM.trackerColNMCB = colNMCB

    for idx, charKey in ipairs(orderedKeys) do
        local data = PreyMateDB.trackerCharacters[charKey]
        local row = { widgets = {} }
        local key = charKey

        local rowFrame = CreateFrame("Frame", nil, panel)
        rowFrame:SetSize(480, TRACKER_ROW_HEIGHT)
        rowFrame:SetPoint("TOPLEFT", 0, yOff)
        rowFrame.charKey = charKey
        rowFrame.orderIndex = idx

        -- Drag handle
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
                local relY = cursorY - panelTop
                local distFromStart = PM.dragCharRowStartY - relY
                local numRows = #PM.trackerRowFrames

                local gap = math.floor(distFromStart / TRACKER_ROW_HEIGHT + 0.5) + 1
                gap = math.max(1, math.min(gap, numRows + 1))

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

        -- Clear button
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