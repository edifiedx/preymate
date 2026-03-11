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

local AUTOCOLLECT_DELAY = 0.5  -- seconds to wait after ShowQuestComplete before calling GetQuestReward

PM.ADDON_NAME = "PreyMate"
PM.PREFIX = "[|cffcc3333Prey|rMate]"

PM.PROFILE_DEFAULTS = {
    debug = false,
    autoAccept = false,
    autoPayFee = false,
    preyLevel = PREY_NORMAL,
    autoComplete = false,        -- open reward frame and complete the quest automatically
    autoCollect = false,         -- automatically pick a reward if choices are presented
    autoCollectReward = REWARD_GOLD,
}

local DEBUG = false

local function log(...)
    if DEBUG then print(PM.PREFIX, ...) end
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

---------------------------------------------------------------------
-- Quest Tracking
---------------------------------------------------------------------
local preyWorldQuestIDs = {
    91594, 91596, 91592, 91601, 91458, 91595,
    91590, 91602, 91207, 91604, 91523, 91591,
}

-- The hunt quest the player is currently on, or nil if none.
-- Set on QUEST_ACCEPTED (or restored at login via GetActivePreyQuest),
-- cleared when the target is revealed (2nd objective unlocked).
PM.activeHuntQuestID = nil

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
                log("Now tracking!")
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

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == PM.ADDON_NAME then
        if not PreyMateDB then PreyMateDB = {} end
        if not PreyMateDB.profiles then PreyMateDB.profiles = {} end
        if not PreyMateDB.characterProfiles then PreyMateDB.characterProfiles = {} end

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

    elseif event == "PLAYER_ENTERING_WORLD" then
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
                    log("Auto-completing quest on recovery")
                    PM.activeHuntQuestID = nil
                    ShowQuestComplete(resumeID)
                    if profile.autoCollect then
                        C_Timer.After(AUTOCOLLECT_DELAY, function()
                            local choices = GetNumQuestChoices()
                            log("Auto-collecting reward, choices=", choices, "index=", profile.autoCollectReward)
                            GetQuestReward(choices > 1 and profile.autoCollectReward or 0)
                        end)
                    end
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
            log("Hunt quest accepted! Finding world quest...")
            C_Timer.After(0.5, function() FindAndTrackPreyWorldQuest(0) end)
        end

    elseif event == "QUEST_REMOVED" then
        if arg1 == PM.activeHuntQuestID then
            log("Hunt quest removed, clearing tracking")
            PM.activeHuntQuestID = nil
        end

    elseif event == "QUEST_LOG_UPDATE" then
        -- Fast exit: only process when we know we're on a hunt quest
        local qID = PM.activeHuntQuestID
        if not qID then return end

        local profile = PM:GetProfile()

        if C_QuestLog.IsComplete(qID) then
            log("Hunt quest complete")
            if profile.autoComplete then
                log("Auto-completing quest")
                PM.activeHuntQuestID = nil
                ShowQuestComplete(qID)
                if profile.autoCollect then
                    C_Timer.After(AUTOCOLLECT_DELAY, function()
                        local choices = GetNumQuestChoices()
                        log("Auto-collecting reward, choices=", choices, "index=", profile.autoCollectReward)
                        GetQuestReward(choices > 1 and profile.autoCollectReward or 0)
                    end)
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
SLASH_PREYMATE1 = "/pm"
SlashCmdList["PREYMATE"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "track" then
        FindAndTrackPreyWorldQuest()
    elseif PM.settingsCategory then
        Settings.OpenToCategory(PM.settingsCategory.ID)
    else
        print(PM.PREFIX, "Settings not initialized yet")
    end
end