---------------------------------------------------------------------
-- PreyMate.lua — Core addon logic
---------------------------------------------------------------------
PreyMate = {}
local PM = PreyMate
local PREY_NORMAL    = 1
local PREY_HARD      = 2
local PREY_NIGHTMARE = 3

local REWARD_GOLD      = 1
local REWARD_MARL      = 2
local REWARD_DAWNCREST = 3
local REWARD_ANGUISH   = 4

PM.ACCEPT_SHIFT = 1   -- Shift-click to accept, normal click = manual
PM.ACCEPT_CLICK = 2   -- Normal click to accept, Shift = skip

PM.LCLICK_TRACK    = 1  -- Left-click tracks hunt
PM.LCLICK_SETTINGS = 2  -- Left-click opens settings
PM.LCLICK_STATS    = 3  -- Left-click prints session stats

local AUTOCOLLECT_DELAY = 0.5  -- seconds to wait after ShowQuestComplete before calling GetQuestReward

-- Remnants of Anguish currency ID (confirmed via C_CurrencyInfo.GetCurrencyInfo(3392))
local ANGUISH_CURRENCY_ID = 3392

-- Currency IDs for hunt quest rewards (6th return of GetQuestItemInfo)
-- Gold pouch is an item, not a currency — matched by elimination
local REWARD_CURRENCY_IDS = {
    [3316] = REWARD_MARL,       -- Voidlight Marl
    [3341] = REWARD_DAWNCREST,  -- Veteran Dawncrest
    [3383] = REWARD_DAWNCREST,  -- Adventurer Dawncrest
    [3343] = REWARD_DAWNCREST,  -- Champion Dawncrest
    [3345] = REWARD_DAWNCREST,  -- Hero Dawncrest
    [3347] = REWARD_DAWNCREST,  -- Myth Dawncrest
    [3392] = REWARD_ANGUISH,    -- Remnant of Anguish
}

PM.ADDON_NAME = "PreyMate"
PM.PREFIX = "[|cffcc3333Prey|rMate]"

PM.PROFILE_DEFAULTS = {
    debug = false,
    autoAccept = false,
    autoAcceptMode = 1,          -- 1 = shift-click to accept, 2 = click to accept (shift to skip)
    autoPayFee = false,
    preyLevel = PREY_NORMAL,
    autoComplete = true,         -- open reward frame and complete the quest automatically
    autoCollect = false,         -- automatically pick a reward if choices are presented
    autoCollectReward = REWARD_DAWNCREST,
    showMinimapIcon = true,
    leftClickAction = 1,         -- 1 = track hunt, 2 = open settings
    showStatBalance = true,      -- show current Anguish balance in minimap tooltip
    showStatSession = true,      -- show session delta in minimap tooltip
    showStatPerHunt = true,      -- show per-hunt average in minimap tooltip
    showStatPerHour = false,     -- show per-hour rate in minimap tooltip
    showWeeklyTracker = true,    -- show weekly hunt tracker in minimap tooltip
    trackerShowNormal = true,    -- default: show Normal gear column for new characters
    trackerShowHard = true,      -- default: show Hard gear column for new characters
    trackerShowNightmare = true, -- default: show Nightmare gear column for new characters
}

-- Shared display names (used by stats and context menus across modules)
PM.PREY_LEVEL_NAMES = { "Normal", "Hard", "Nightmare" }
PM.REWARD_NAMES     = { "Gold", "Voidlight Marl", "Dawncrest", "Anguish" }

-- Session stats — reset each login, never persisted to SavedVariables
PM.session = {
    huntsStarted     = 0,
    huntsCompleted   = 0,
    autoAccepts      = 0,
    autoFeesPaid     = 0,
    difficultyCounts = { 0, 0, 0 },      -- [1]=Normal  [2]=Hard  [3]=Nightmare
    rewardCounts     = { 0, 0, 0, 0 },   -- [1]=Gold  [2]=Marl  [3]=Dawncrest  [4]=Anguish
    -- Anguish currency tracking
    sessionStartAnguish = nil,  -- quantity at start of this segment (resets each reload)
    sessionStartTime    = nil,  -- GetTime() at start of this segment
    huntStartAnguish    = nil,  -- quantity when current hunt began (pre-fee)
    lastHuntDelta       = nil,  -- net Anguish change for the most recently finished hunt
    -- Carryover from previous segment — survives /reload
    carryoverDelta      = 0,    -- accumulated Anguish delta before last reload
    carryoverElapsed    = 0,    -- accumulated seconds elapsed before last reload
}

local DEBUG = false

local function log(...)
    if DEBUG then print(PM.PREFIX, ...) end
end

local function info(...)
    print(PM.PREFIX, ...)
end

-- Expected slot order: 1=Gold, 2=Marl, 3=Dawncrest, 4=Anguish
-- If this ever changes, FindRewardChoiceIndex handles it via currency ID matching
local EXPECTED_SLOT_REWARD = {
    [1] = REWARD_GOLD,
    [2] = REWARD_MARL,
    [3] = REWARD_DAWNCREST,
    [4] = REWARD_ANGUISH,
}

-- Log all quest reward choices and verify they match expected positions.
local function LogRewardChoices(choices)
    log("Reward choices:", choices)
    local orderMatch = true
    for i = 1, choices do
        local name, _, _, _, _, id = GetQuestItemInfo("choice", i)
        local cInfo = C_CurrencyInfo.GetCurrencyInfo(id)
        local label = cInfo and cInfo.name or name
        local mapped = REWARD_CURRENCY_IDS[id] or REWARD_GOLD
        local expected = EXPECTED_SLOT_REWARD[i]
        local ok = (mapped == expected)
        if not ok then orderMatch = false end
        log("  Slot", i, ":", label, "(id:", id, ")",
            "=>", PM.REWARD_NAMES[mapped] or "?",
            ok and "|cff00ff00OK|r" or "|cffff0000MISMATCH (expected " .. (PM.REWARD_NAMES[expected] or "?") .. ")|r")
    end
    if orderMatch then
        log("  Slot order: |cff00ff00VERIFIED|r — matches expected layout")
    else
        log("  Slot order: |cffff9900DIFFERS|r — using currency ID matching (safe)")
    end
end

-- Scan quest reward choices by currency ID to find the correct slot index.
-- Returns the 1-based choice index for GetQuestReward(), or nil if not found.
local function FindRewardChoiceIndex(wantedReward)
    local choices = GetNumQuestChoices()
    if choices <= 1 then return choices end  -- 0 or 1 = no choice needed
    LogRewardChoices(choices)
    log("Looking for reward type:", PM.REWARD_NAMES[wantedReward] or "?", "(const:", wantedReward, ")")
    -- Build ID list for all slots for the info summary
    local slotIDs = {}
    for i = 1, choices do
        local _, _, _, _, _, id = GetQuestItemInfo("choice", i)
        slotIDs[i] = id
    end
    local idList = "{" .. table.concat(slotIDs, ", ") .. "}"
    -- Gold: find the slot that is NOT a known currency
    if wantedReward == REWARD_GOLD then
        for i = 1, choices do
            local name, _, _, _, _, id = GetQuestItemInfo("choice", i)
            if not REWARD_CURRENCY_IDS[id] then
                log("  -> MATCH slot", i, ":", name, "(id:", id, ") — not a known currency, treating as Gold")
                info("Rewards", idList, "Selecting (" .. i .. "){" .. id .. "} \"" .. name .. "\"")
                return i
            end
        end
    else
        -- Currency reward: match by currency ID
        for i = 1, choices do
            local name, _, _, _, _, id = GetQuestItemInfo("choice", i)
            local mapped = REWARD_CURRENCY_IDS[id]
            if mapped == wantedReward then
                local cInfo = C_CurrencyInfo.GetCurrencyInfo(id)
                local label = cInfo and cInfo.name or name
                log("  -> MATCH slot", i, ":", label, "(id:", id, ") maps to", PM.REWARD_NAMES[mapped] or "?")
                info("Rewards", idList, "Selecting (" .. i .. "){" .. id .. "} \"" .. label .. "\"")
                return i
            end
        end
    end
    log("  -> NO MATCH found for", PM.REWARD_NAMES[wantedReward] or "?")
    info("Rewards", idList, "— could not find " .. (PM.REWARD_NAMES[wantedReward] or "?"))
    return nil  -- not found
end

function PM:GetCharKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

function PM:GetProfile()
    local charKey = self:GetCharKey()
    local profileName = PreyMateDB.characterProfiles[charKey] or "Default"
    if not PreyMateDB.profiles[profileName] then
        profileName = "Default"
        PreyMateDB.characterProfiles[charKey] = "Default"
    end
    return PreyMateDB.profiles[profileName], profileName
end

function PM:ApplyProfile()
    local profile = self:GetProfile()
    DEBUG = profile.debug
    PM.debug = DEBUG
end

function PM:GetProfileNames()
    local names = {}
    for name in pairs(PreyMateDB.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function PM:SwitchProfile(name)
    if not PreyMateDB.profiles[name] then return end
    PreyMateDB.characterProfiles[self:GetCharKey()] = name
    self:ApplyProfile()
    if self.RefreshOptions then self:RefreshOptions() end
end

function PM:CloneProfile()
    local src, _ = self:GetProfile()
    local destName = self:GetCharKey()
    if PreyMateDB.profiles[destName] then
        local i = 2
        while PreyMateDB.profiles[destName .. " (" .. i .. ")"] do
            i = i + 1
        end
        destName = destName .. " (" .. i .. ")"
    end
    local copy = {}
    for k, v in pairs(src) do copy[k] = v end
    PreyMateDB.profiles[destName] = copy
    self:SwitchProfile(destName)
end

function PM:RenameProfile(oldName, newName)
    newName = newName:match("^%s*(.-)%s*$")
    if newName == "" then
        print(PM.PREFIX, "Profile name cannot be empty.")
        return
    end
    if PreyMateDB.profiles[newName] then
        print(PM.PREFIX, "A profile named '" .. newName .. "' already exists.")
        return
    end
    PreyMateDB.profiles[newName] = PreyMateDB.profiles[oldName]
    PreyMateDB.profiles[oldName] = nil
    for charKey, pName in pairs(PreyMateDB.characterProfiles) do
        if pName == oldName then
            PreyMateDB.characterProfiles[charKey] = newName
        end
    end
    if self.RefreshOptions then self:RefreshOptions() end
end

function PM:DeleteProfile(name)
    local names = self:GetProfileNames()
    if #names <= 1 then return end
    local fallback = names[1] ~= name and names[1] or names[2]
    local charKey = self:GetCharKey()
    local wasActive = (PreyMateDB.characterProfiles[charKey] or "Default") == name
    for ck, pn in pairs(PreyMateDB.characterProfiles) do
        if pn == name then
            PreyMateDB.characterProfiles[ck] = fallback
        end
    end
    PreyMateDB.profiles[name] = nil
    self:ApplyProfile()
    if self.RefreshOptions then self:RefreshOptions() end
    if wasActive and #names > 2 then
        StaticPopup_Show("PREYMATE_POST_DELETE", fallback)
    end
end

function PM:RestoreDefaults()
    local profile = self:GetProfile()
    for k, v in pairs(PM.PROFILE_DEFAULTS) do
        profile[k] = v
    end
    self:ApplyProfile()
    if self.RefreshOptions then self:RefreshOptions() end
end

-- Returns the player's current Anguish quantity, or nil if not available.
function PM:GetAnguish()
    local info = C_CurrencyInfo.GetCurrencyInfo(ANGUISH_CURRENCY_ID)
    return info and info.quantity or nil
end

---------------------------------------------------------------------
-- Quest Tracking
---------------------------------------------------------------------
local preyWorldQuestIDs = {
    91594, 91596, 91592, 91601, 91458, 91595,
    91590, 91602, 91207, 91604, 91523, 91591,
}

local preyQuestTypeMap = {
    -- Apex Predator: kill enemies
    [91601] = "Kill Enemies", [91602] = "Kill Enemies",
    [91604] = "Kill Enemies", [91207] = "Kill Enemies",
    -- Concealed Threat: deactivate shrines
    [91523] = "Deactivate Shrines", [91592] = "Deactivate Shrines",
    [91590] = "Deactivate Shrines", [91591] = "Deactivate Shrines",
    -- Endurance Hunter: chase
    [91596] = "Chase", [91595] = "Chase",
    [91458] = "Chase",  [91594] = "Chase",
}

-- The hunt quest the player is currently on, or nil if none.
-- Set on QUEST_ACCEPTED (or restored at login via GetActivePreyQuest),
-- cleared when the target is revealed (2nd objective unlocked).
PM.activeHuntQuestID  = nil
PM.activeWorldQuestType = nil  -- "Kill Enemies", "Deactivate Shrines", or "Chase"

local function FindAndTrackPreyWorldQuest(retryCount)
    retryCount = retryCount or 0
    log("Searching for active Prey world quest..." .. (retryCount > 0 and (" (retry " .. retryCount .. ")") or ""))

    for _, qID in ipairs(preyWorldQuestIDs) do
        if C_TaskQuest.IsActive(qID) then
            local title = C_TaskQuest.GetQuestInfoByQuestID(qID)
            log("Found:", qID, title)

            -- Always add to watch list first, then super-track
            C_QuestLog.AddQuestWatch(qID)
            C_SuperTrack.SetSuperTrackedQuestID(qID)

            if C_SuperTrack.GetSuperTrackedQuestID() == qID then
                PM.activeWorldQuestType = preyQuestTypeMap[qID]
                log("Now tracking!", PM.activeWorldQuestType or "(unknown type)")
                return true
            end

            -- Didn't stick — retry up to 4 times with increasing delays
            if retryCount < 4 then
                local delay = 1 * (retryCount + 1) -- 1s, 2s, 3s, 4s
                log("Track didn't stick, retrying in", delay, "sec")
                C_Timer.After(delay, function() FindAndTrackPreyWorldQuest(retryCount + 1) end)
                return false
            end

            log("Failed to super-track after retries")
            return false
        end
    end

    -- No quest found yet — if this was triggered by an event, retry in case data is still loading
    if retryCount < 4 then
        local delay = 1 * (retryCount + 1)
        log("No active world quest found, retrying in", delay, "sec")
        C_Timer.After(delay, function() FindAndTrackPreyWorldQuest(retryCount + 1) end)
        return false
    end

    log("No active world quest found")
    return false
end

-- Schedules a 2-second delayed snapshot of the hunt's Anguish delta.
-- The delay lets both the fee deduction and the reward credit settle
-- before we read the currency. Guards against double-scheduling.
local pendingHuntDeltaCapture = false
local function ScheduleHuntDeltaCapture()
    if pendingHuntDeltaCapture then return end
    local startAnguish = PM.session.huntStartAnguish
    if not startAnguish then return end
    pendingHuntDeltaCapture = true
    C_Timer.After(2, function()
        pendingHuntDeltaCapture = false
        local endAnguish = PM:GetAnguish()
        if endAnguish then
            PM.session.lastHuntDelta = endAnguish - startAnguish
        end
        PM.session.huntStartAnguish = nil
    end)
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == PM.ADDON_NAME then
        if not PreyMateDB then PreyMateDB = {} end
        if not PreyMateDB.profiles then PreyMateDB.profiles = {} end
        if not PreyMateDB.characterProfiles then PreyMateDB.characterProfiles = {} end

        if not PreyMateDB.trackerCharacters then PreyMateDB.trackerCharacters = {} end
        if not PreyMateDB.trackerOrder then PreyMateDB.trackerOrder = {} end

        if not PreyMateDB.profiles["Default"] then
            PreyMateDB.profiles["Default"] = {}
        end
        for _, profile in pairs(PreyMateDB.profiles) do
            for k, v in pairs(PM.PROFILE_DEFAULTS) do
                if profile[k] == nil then profile[k] = v end
            end
        end

        -- Restore activeHuntQuestID if the player logged in mid-hunt.
        -- This is deferred to PLAYER_ENTERING_WORLD (see below) because
        -- quest data is not available yet at ADDON_LOADED time.

        PM:ApplyProfile()
        PM:InitSettings()
        self:UnregisterEvent("ADDON_LOADED")
        log("Loaded! Use /pm track to manually find and track")

    elseif event == "PLAYER_LOGOUT" then
        -- Snapshot the full session so a /reload can resume without losing progress.
        local endAnguish = PM:GetAnguish()
        local segDelta   = (endAnguish and PM.session.sessionStartAnguish)
                            and (endAnguish - PM.session.sessionStartAnguish) or 0
        local totalDelta   = segDelta + (PM.session.carryoverDelta or 0)
        local segElapsed   = PM.session.sessionStartTime
                             and (GetTime() - PM.session.sessionStartTime) or 0
        local totalElapsed = math.max(segElapsed + (PM.session.carryoverElapsed or 0), 0)
        PreyMateDB.currentSession = {
            savedAt          = GetServerTime(),
            anguishDelta     = totalDelta,
            elapsedSeconds   = totalElapsed,
            huntsCompleted   = PM.session.huntsCompleted,
            huntsStarted     = PM.session.huntsStarted,
            lastHuntDelta    = PM.session.lastHuntDelta,
            rewardCounts     = {
                PM.session.rewardCounts[1], PM.session.rewardCounts[2],
                PM.session.rewardCounts[3], PM.session.rewardCounts[4],
            },
            difficultyCounts = {
                PM.session.difficultyCounts[1],
                PM.session.difficultyCounts[2],
                PM.session.difficultyCounts[3],
            },
        }
        if PM.session.huntsCompleted > 0 then
            PreyMateDB.lastSession = {
                anguishDelta   = totalDelta,
                huntsCompleted = PM.session.huntsCompleted,
                elapsedSeconds = totalElapsed,
            }
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Restore session counters if reloading within 5 minutes; otherwise start fresh.
        local cs = PreyMateDB and PreyMateDB.currentSession
        if cs and cs.savedAt and (GetServerTime() - cs.savedAt) < 300 then
            PM.session.huntsCompleted    = cs.huntsCompleted
            PM.session.huntsStarted      = cs.huntsStarted
            PM.session.lastHuntDelta     = cs.lastHuntDelta
            PM.session.rewardCounts      = {
                cs.rewardCounts[1], cs.rewardCounts[2],
                cs.rewardCounts[3], cs.rewardCounts[4],
            }
            PM.session.difficultyCounts  = {
                cs.difficultyCounts[1],
                cs.difficultyCounts[2],
                cs.difficultyCounts[3],
            }
            PM.session.carryoverDelta    = cs.anguishDelta
            PM.session.carryoverElapsed  = cs.elapsedSeconds
            log("Session restored from reload:", cs.huntsCompleted, "hunts,",
                string.format("%+d", cs.anguishDelta), "Anguish carried over")
        end
        PM.session.sessionStartAnguish = PM:GetAnguish()
        PM.session.sessionStartTime = GetTime()

        -- Register this character for the weekly tracker (deferred scan)
        PM:RegisterTrackerCharacter()

        -- Quest data is now available. Restore tracking if we're mid-hunt.
        local resumeID = C_QuestLog.GetActivePreyQuest()
        log("Login/reload recovery: GetActivePreyQuest() =", tostring(resumeID))
        if resumeID then
            PM.activeHuntQuestID = resumeID
            local numObj = C_QuestLog.GetNumQuestObjectives(resumeID)
            log("Hunt quest objectives:", tostring(numObj))
            if C_QuestLog.IsComplete(resumeID) then
                log("Hunt already complete at login/reload")
                local profile = PM:GetProfile()
                if profile.autoComplete then
                    log("Auto-completing quest on recovery (delayed 1s for UI)")
                    PM.activeHuntQuestID = nil
                    local RECOVERY_DELAY = 1
                    local RECOVERY_COLLECT_DELAY = 1.5  -- longer than normal; frame needs time after ShowQuestComplete on recovery
                    C_Timer.After(RECOVERY_DELAY, function()
                        ShowQuestComplete(resumeID)
                        C_Timer.After(RECOVERY_COLLECT_DELAY, function()
                            if profile.autoCollect then
                                local idx = FindRewardChoiceIndex(profile.autoCollectReward)
                                log("Auto-collecting reward, wanted=", profile.autoCollectReward, "slot=", tostring(idx))
                                if idx then
                                    log("Calling GetQuestReward(", idx, ")")
                                    GetQuestReward(idx)
                                    log("GetQuestReward returned")
                                end
                            else
                                LogRewardChoices(GetNumQuestChoices())
                            end
                        end)
                    end)
                end
            elseif numObj == 2 then
                log("Target already revealed, super-tracking hunt quest")
                C_SuperTrack.SetSuperTrackedQuestID(resumeID)
            else
                log("Target not yet revealed, finding world quest...")
                C_Timer.After(0.5, function() FindAndTrackPreyWorldQuest(0) end)
            end
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    elseif event == "QUEST_ACCEPTED" then
        if C_QuestLog.GetActivePreyQuest() == arg1 then
            PM.activeHuntQuestID = arg1
            PM.session.huntsStarted = PM.session.huntsStarted + 1
            -- Auto-accept path sets huntStartAnguish on Page 1 gossip (pre-fee).
            -- For manual accepts, snapshot here as a fallback.
            if not PM.session.huntStartAnguish then
                PM.session.huntStartAnguish = PM:GetAnguish()
            end
            log("Hunt quest accepted! Finding world quest...")
            C_Timer.After(0.5, function() FindAndTrackPreyWorldQuest(0) end)
        end

    elseif event == "QUEST_REMOVED" then
        if arg1 == PM.activeHuntQuestID then
            log("Hunt quest removed, clearing tracking")
            ScheduleHuntDeltaCapture()
            PM.activeHuntQuestID   = nil
            PM.activeWorldQuestType = nil
            PM.activeHuntComplete  = false
            -- Re-scan after turn-in so weekly flags are current
            local TURN_IN_SCAN_DELAY = 1
            local TURN_IN_RETRY_DELAY = 3
            C_Timer.After(TURN_IN_SCAN_DELAY, function() PM:RefreshTrackerScan() end)
            C_Timer.After(TURN_IN_RETRY_DELAY, function() PM:RefreshTrackerScan() end)
        end

    elseif event == "QUEST_LOG_UPDATE" then
        -- Fast exit: only process when we know we're on a hunt quest
        local qID = PM.activeHuntQuestID
        if not qID then return end

        local profile = PM:GetProfile()

        if C_QuestLog.IsComplete(qID) then
            if not PM.activeHuntComplete then
                PM.activeHuntComplete = true
                PM.session.huntsCompleted = PM.session.huntsCompleted + 1
                log("Hunt quest complete")
                if profile.autoComplete then
                    log("Auto-completing quest")
                    ShowQuestComplete(qID)
                    if profile.autoCollect then
                        C_Timer.After(AUTOCOLLECT_DELAY, function()
                            local idx = FindRewardChoiceIndex(profile.autoCollectReward)
                            log("Auto-collecting reward, wanted=", profile.autoCollectReward, "slot=", tostring(idx))
                            if idx then
                                PM.session.rewardCounts[profile.autoCollectReward] = (PM.session.rewardCounts[profile.autoCollectReward] or 0) + 1
                                GetQuestReward(idx)
                            end
                            ScheduleHuntDeltaCapture()  -- runs 2s later, after reward credits
                        end)
                    else
                        C_Timer.After(AUTOCOLLECT_DELAY, function()
                            LogRewardChoices(GetNumQuestChoices())
                        end)
                        ScheduleHuntDeltaCapture()  -- player picks reward manually; snapshot anyway
                    end
                end
            end
        elseif C_QuestLog.GetNumQuestObjectives(qID) == 2 then
            log("Target revealed! Tracking hunt quest")
            C_SuperTrack.SetSuperTrackedQuestID(qID)
        end
    end
end)

---------------------------------------------------------------------
-- Slash Commands
---------------------------------------------------------------------
function PM:Track()
    FindAndTrackPreyWorldQuest()
end

function PM:PrintSessionStats()
    local s = self.session
    print(self.PREFIX, "|cffffff00Session Stats|r")
    print(self.PREFIX, "  Hunts started:  ", s.huntsStarted)
    print(self.PREFIX, "  Hunts completed:", s.huntsCompleted)
    if s.autoAccepts > 0 then
        print(self.PREFIX, "  Auto-accepted:  ", s.autoAccepts)
    end
    if s.autoFeesPaid > 0 then
        print(self.PREFIX, "  Fees auto-paid: ", s.autoFeesPaid)
    end
    local diffAny = false
    for i = 1, 3 do if (s.difficultyCounts[i] or 0) > 0 then diffAny = true; break end end
    if diffAny then
        print(self.PREFIX, "  Difficulty:")
        for i = 1, 3 do
            if (s.difficultyCounts[i] or 0) > 0 then
                print(self.PREFIX, "    " .. self.PREY_LEVEL_NAMES[i] .. ": " .. s.difficultyCounts[i])
            end
        end
    end
    local rewardAny = false
    for i = 1, 4 do if (s.rewardCounts[i] or 0) > 0 then rewardAny = true; break end end
    if rewardAny then
        print(self.PREFIX, "  Rewards:")
        for i = 1, 4 do
            if (s.rewardCounts[i] or 0) > 0 then
                print(self.PREFIX, "    " .. self.REWARD_NAMES[i] .. ": " .. s.rewardCounts[i])
            end
        end
    end
end



SLASH_PREYMATE1 = "/pm"
SlashCmdList["PREYMATE"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "track" then
        PM:Track()
    elseif msg == "stats" then
        PM:PrintSessionStats()
    elseif msg == "hunts" then
        PM:DebugWeeklyHunts()
    elseif msg == "journey" then
        PM:DebugJourneyRank()
    elseif msg:match("^fakerank") then
        local rank, earned = msg:match("^fakerank%s+(%d+)%s+(%d+)")
        if rank then
            PM.debugJourneyOverride = {
                rank = tonumber(rank),
                earned = tonumber(earned),
                threshold = 4000,
            }
            print(PM.PREFIX, string.format("Faking Journey Rank %s (%s/4000) — hover minimap to see tooltip", rank, earned))
        else
            PM.debugJourneyOverride = nil
            print(PM.PREFIX, "Journey rank override cleared")
        end
    elseif PM.settingsCategory then
        Settings.OpenToCategory(PM.settingsCategory.ID)
    else
        print(PM.PREFIX, "Settings not initialized yet")
    end
end

---------------------------------------------------------------------
-- Debug: Journey rank info
---------------------------------------------------------------------
function PM:DebugJourneyRank()
    local journey = self:GetJourneyInfo()
    if journey then
        print(self.PREFIX, string.format(
            "|cffffff00Journey|r — Rank %d, Progress %d/%d",
            journey.rank, journey.earned, journey.threshold
        ))
    else
        print(self.PREFIX, "Journey rank data not available")
    end
end