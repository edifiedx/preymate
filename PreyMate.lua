---------------------------------------------------------------------
-- PreyMate.lua — Core addon logic
---------------------------------------------------------------------
PreyMate = {}
local PM = PreyMate
local PREY_NORMAL = 1
local PREY_HARD = 2
local PREY_NIGHTMARE = 3

PM.ADDON_NAME = "PreyMate"
PM.PREFIX = "[|cffcc3333Prey|rMate]"

PM.PROFILE_DEFAULTS = {
    debug = false,
    autoAccept = false,
    autoPayFee = false,
    preyLevel = PREY_NORMAL,
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
frame:RegisterEvent("ADDON_LOADED")

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

        PM:ApplyProfile()
        PM:InitSettings()
        self:UnregisterEvent("ADDON_LOADED")
        log("Loaded! Use /pm track to manually find and track")

    elseif event == "QUEST_ACCEPTED" then
        local questIDs = C_QuestLine.GetQuestLineQuests(5945)
        if questIDs then
            for _, id in ipairs(questIDs) do
                if id == arg1 then
                    log("Hunt quest accepted! Finding world quest...")
                    C_Timer.After(0.5, function() FindAndTrackPreyWorldQuest(0) end)
                    return
                end
            end
        end

    elseif event == "QUEST_LOG_UPDATE" then
        local questIDs = C_QuestLine.GetQuestLineQuests(5945)
        if questIDs then
            for _, qID in ipairs(questIDs) do
                if C_QuestLog.IsOnQuest(qID) then
                    if C_QuestLog.GetNumQuestObjectives(qID) == 2 then
                        log("Target revealed! Tracking hunt quest")
                        C_SuperTrack.SetSuperTrackedQuestID(qID)
                        return
                    end
                end
            end
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