---------------------------------------------------------------------
-- PreyMate_Minimap.lua — Minimap button (LibDBIcon-1.0)
---------------------------------------------------------------------
local PM = PreyMate

local PREY_LEVELS = { "Normal", "Hard", "Nightmare" }

local TRAP_ITEM_ID = 255825
local TRAP_MAX     = 5

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
-- Anguish tooltip helpers
---------------------------------------------------------------------
local function AngDeltaColor(delta)
    if delta > 0 then return 0.2, 1, 0.2
    elseif delta < 0 then return 1, 0.35, 0.35
    else return 0.7, 0.7, 0.7 end
end

local function FormatAnguishDelta(delta)
    if delta >= 0 then
        return string.format("+%d Anguish", delta)
    else
        return string.format("%d Anguish", delta)
    end
end

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

        local profileSub = root:CreateButton("Switch Profile")
        for _, n in ipairs(PM:GetProfileNames()) do
            local name = n
            profileSub:CreateRadio(name,
                function()
                    local _, current = PM:GetProfile()
                    return current == name
                end,
                function()
                    PM:SwitchProfile(name)
                end
            )
        end

        root:CreateDivider()

        root:CreateButton("Print Session Stats", function() PM:PrintSessionStats() end)
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
                local action = PM:GetProfile().leftClickAction
                if action == PM.LCLICK_SETTINGS then
                    if PM.settingsCategory then
                        Settings.OpenToCategory(PM.settingsCategory.ID)
                    end
                elseif action == PM.LCLICK_STATS then
                    PM:PrintSessionStats()
                else
                    PM:Track()
                end
            elseif button == "RightButton" then
                ShowContextMenu(self)
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText(PM.PREFIX)

            local profile = PM:GetProfile()

            -- Trap count
            local traps = GetItemCount(TRAP_ITEM_ID)
            if traps then
                local r, g, b = 1, 1, 1
                if traps == 0 then r, g, b = 1, 0.35, 0.35
                elseif traps < TRAP_MAX then r, g, b = 1, 0.85, 0.1 end
                tooltip:AddDoubleLine("Traps:", traps .. "/" .. TRAP_MAX, 0.7, 0.7, 0.7, r, g, b)
            end

            -- Active world quest type
            if PM.activeWorldQuestType then
                tooltip:AddDoubleLine("Hunt Type:", PM.activeWorldQuestType, 0.7, 0.7, 0.7, 1, 1, 1)
            end

            -- Active automation settings
            if profile.autoAccept then
                local levelName = PM.PREY_LEVEL_NAMES[profile.preyLevel] or "?"
                tooltip:AddDoubleLine("Hunt Level:", levelName, 0.7, 0.7, 0.7, 1, 1, 1)
            end
            if profile.autoCollect then
                local rewardName = PM.REWARD_NAMES[profile.autoCollectReward] or "?"
                tooltip:AddDoubleLine("Reward:", rewardName, 0.7, 0.7, 0.7, 1, 1, 1)
            end

            -- Weekly hunt tracker (above Anguish stats)
            if profile.showWeeklyTracker then
                tooltip:AddLine(" ")
                local warband = PM:ScanWarbandHunts()
                local BONUS_THRESHOLD = 4
                local bonusDone = math.min(warband.total, BONUS_THRESHOLD)
                local bonusR, bonusG, bonusB = 1, 0.85, 0.1
                if bonusDone >= BONUS_THRESHOLD then bonusR, bonusG, bonusB = 0.2, 1, 0.2 end
                tooltip:AddDoubleLine("Journey Bonus:", bonusDone .. "/" .. BONUS_THRESHOLD, 0.7, 0.7, 0.7, bonusR, bonusG, bonusB)

                -- Per-character item rewards by difficulty
                if PreyMateDB.trackerCharacters then
                    local orderedKeys = PM:GetTrackerOrder()
                    local hasAnyChar = false
                    for _, charKey in ipairs(orderedKeys) do
                        local data = PreyMateDB.trackerCharacters[charKey]
                        if data.showInTooltip and data.lastScan then hasAnyChar = true; break end
                    end
                    if hasAnyChar then
                        tooltip:AddLine("Item Rewards:", 0.7, 0.7, 0.7)
                    end
                    for _, charKey in ipairs(orderedKeys) do
                        local data = PreyMateDB.trackerCharacters[charKey]
                        if data.showInTooltip and data.lastScan then
                            local sc = data.lastScan
                            local charName = charKey:match("^(.+) %- ") or charKey
                            local MAX_ITEMS_PER_DIFFICULTY = 2
                            -- Fixed-width columns: each slot is the same width
                            -- whether shown, hidden, or blank padding
                            local COL_PAD = "        "  -- padding for hidden columns
                            local function fmtCol(label, count)
                                local v = math.min(count, MAX_ITEMS_PER_DIFFICULTY)
                                local cr, cg, cb = 1, 0.35, 0.35
                                if v >= 2 then cr, cg, cb = 0.2, 1, 0.2
                                elseif v == 1 then cr, cg, cb = 1, 0.65, 0 end
                                return string.format("|cff%02x%02x%02x%s:%d|r", cr * 255, cg * 255, cb * 255, label, v)
                            end
                            local slots = {}
                            slots[#slots + 1] = (data.showNormal ~= false) and fmtCol("N", sc.Normal or 0) or COL_PAD
                            slots[#slots + 1] = (data.showHard ~= false) and fmtCol("H", sc.Hard or 0) or COL_PAD
                            slots[#slots + 1] = (data.showNightmare ~= false) and fmtCol("NM", sc.Nightmare or 0) or COL_PAD
                            -- Only show the line if at least one column is visible
                            local hasAny = (data.showNormal ~= false) or (data.showHard ~= false) or (data.showNightmare ~= false)
                            if hasAny then
                                tooltip:AddDoubleLine("  " .. charName, table.concat(slots, "  "), 0.5, 0.5, 0.5, 1, 1, 1)
                            end
                        end
                    end
                end
            end

            -- Anguish stats
            local currentAnguish = PM:GetAnguish()
            local s = PM.session
            local segDelta     = (currentAnguish and s.sessionStartAnguish)
                                  and (currentAnguish - s.sessionStartAnguish) or 0
            local totalDelta   = segDelta + (s.carryoverDelta or 0)
            local totalElapsed = (s.sessionStartTime and (GetTime() - s.sessionStartTime) or 0)
                                + (s.carryoverElapsed or 0)

            local hasCurrentHunt = PM.activeHuntQuestID and s.huntStartAnguish
            local hasLastHunt    = s.lastHuntDelta ~= nil
            local hasSession     = s.huntsCompleted > 0
            local hasLastSession = PreyMateDB and PreyMateDB.lastSession
                                   and PreyMateDB.lastSession.huntsCompleted > 0

            local anyStats = currentAnguish ~= nil and (
                profile.showStatBalance or hasCurrentHunt or hasLastHunt or
                hasSession or hasLastSession
            )

            if anyStats then
                tooltip:AddLine(" ")

                if profile.showStatBalance then
                    tooltip:AddDoubleLine("Anguish:", string.format("%d", currentAnguish), 0.7, 0.7, 0.7, 1, 1, 1)
                end

                if hasCurrentHunt then
                    local d = currentAnguish - s.huntStartAnguish
                    local r, g, b = AngDeltaColor(d)
                    tooltip:AddDoubleLine("Current hunt:", FormatAnguishDelta(d), 0.7, 0.7, 0.7, r, g, b)
                elseif hasLastHunt then
                    local r, g, b = AngDeltaColor(s.lastHuntDelta)
                    tooltip:AddDoubleLine("Last hunt:", FormatAnguishDelta(s.lastHuntDelta), 0.7, 0.7, 0.7, r, g, b)
                end

                if hasSession then
                    if profile.showStatSession then
                        local r, g, b = AngDeltaColor(totalDelta)
                        tooltip:AddDoubleLine("Session:", FormatAnguishDelta(totalDelta), 0.7, 0.7, 0.7, r, g, b)
                    end
                    if profile.showStatPerHunt then
                        local perHunt = math.floor(totalDelta / s.huntsCompleted + 0.5)
                        local r, g, b = AngDeltaColor(perHunt)
                        tooltip:AddDoubleLine("Per hunt:", FormatAnguishDelta(perHunt), 0.7, 0.7, 0.7, r, g, b)
                    end
                    if profile.showStatPerHour and totalElapsed >= 60 then
                        local perHour = math.floor(totalDelta / totalElapsed * 3600 + 0.5)
                        local r, g, b = AngDeltaColor(perHour)
                        tooltip:AddDoubleLine("Per hour:", FormatAnguishDelta(perHour) .. "/hr", 0.7, 0.7, 0.7, r, g, b)
                    end
                elseif hasLastSession then
                    local ls = PreyMateDB.lastSession
                    if profile.showStatSession then
                        local r, g, b = AngDeltaColor(ls.anguishDelta)
                        tooltip:AddDoubleLine("Last session:", FormatAnguishDelta(ls.anguishDelta), 0.5, 0.5, 0.5, r * 0.7, g * 0.7, b * 0.7)
                    end
                    if profile.showStatPerHunt then
                        local perHunt = math.floor(ls.anguishDelta / ls.huntsCompleted + 0.5)
                        local r, g, b = AngDeltaColor(perHunt)
                        tooltip:AddDoubleLine("Per hunt:", FormatAnguishDelta(perHunt), 0.5, 0.5, 0.5, r * 0.7, g * 0.7, b * 0.7)
                    end
                    if profile.showStatPerHour and ls.elapsedSeconds and ls.elapsedSeconds >= 60 then
                        local perHour = math.floor(ls.anguishDelta / ls.elapsedSeconds * 3600 + 0.5)
                        local r, g, b = AngDeltaColor(perHour)
                        tooltip:AddDoubleLine("Per hour:", FormatAnguishDelta(perHour) .. "/hr", 0.5, 0.5, 0.5, r * 0.7, g * 0.7, b * 0.7)
                    end
                end
            end

            -- Click hints at bottom, muted
            tooltip:AddLine(" ")
            local leftHint = (profile.leftClickAction == PM.LCLICK_SETTINGS) and "Open settings"
                          or (profile.leftClickAction == PM.LCLICK_STATS)    and "Print stats"
                          or "Track hunt"
            tooltip:AddDoubleLine("Left click:", leftHint, 1, 1, 1, 0.55, 0.55, 0.55)
            tooltip:AddDoubleLine("Right click:", "Quick menu", 1, 1, 1, 0.55, 0.55, 0.55)

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