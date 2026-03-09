local DEBUG = false

local function log(...)
    if DEBUG then print(...) end
end

local preyWorldQuestIDs = {
    91594, 91596, 91592, 91601, 91458, 91595, 
    91590, 91602, 91207, 91604, 91523, 91591
}

local function FindAndTrackPreyWQ()
    log("Searching for active Prey world quest...")
    
    for _, qID in ipairs(preyWorldQuestIDs) do
        local isActive = C_TaskQuest.IsActive(qID)
        
        if isActive then
            local title = C_TaskQuest.GetQuestInfoByQuestID(qID)
            log("Found:", qID, title)
            C_SuperTrack.SetSuperTrackedQuestID(qID)
            
            local tracked = C_SuperTrack.GetSuperTrackedQuestID()
            if tracked == qID then
                log("Success!")
            else
                C_QuestLog.AddQuestWatch(qID)
                C_SuperTrack.SetSuperTrackedQuestID(qID)
            end
            return true
        end
    end
    
    log("No active Prey world quest found")
    return false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_LOG_UPDATE")

frame:SetScript("OnEvent", function(self, event, questID)
    if event == "QUEST_ACCEPTED" then
        local questIDs = C_QuestLine.GetQuestLineQuests(5945)
        if questIDs then
            for _, id in ipairs(questIDs) do
                if id == questID then
                    log("Hunt quest accepted! Finding world quest...")
                    C_Timer.After(0.5, FindAndTrackPreyWQ)
                    return
                end
            end
        end
    elseif event == "QUEST_LOG_UPDATE" then
        local questIDs = C_QuestLine.GetQuestLineQuests(5945)
        if questIDs then
            for _, qID in ipairs(questIDs) do
                if C_QuestLog.IsOnQuest(qID) then
                    local numObj = C_QuestLog.GetNumQuestObjectives(qID)
                    if numObj == 2 then
                        log("Target revealed! Tracking hunt quest")
                        C_SuperTrack.SetSuperTrackedQuestID(qID)
                        return
                    end
                end
            end
        end
    end
end)

SLASH_TRACKPREY1 = "/pm track"
SlashCmdList["PREYMATE"] = FindAndTrackPreyWQ

log("Prey auto-tracker loaded! Use /pm track to manually find and track")