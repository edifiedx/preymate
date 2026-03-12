---------------------------------------------------------------------
-- PreyMate_Accept.lua — Auto-accept Prey hunt gossip
---------------------------------------------------------------------
local PM = PreyMate

local NPC_NAME = "Astalor Bloodsworn"
local GOSSIP_OPTION_ID = 134357
local PREY_LEVELS = { "Normal", "Hard", "Nightmare" }

local function log(...)
    if PM.debug then print(PM.PREFIX, ...) end
end

local pendingDifficulty = false
local pendingFallback = nil
local pendingPayFee = false

---------------------------------------------------------------------
-- Difficulty Unavailable Popup
---------------------------------------------------------------------
StaticPopupDialogs["PREYMATE_DIFFICULTY_UNAVAILABLE"] = {
    text = "[|cffcc3333%s|r] difficulty is not available.\n\nUpdate your default to [|cffcc3333%s|r] and start a hunt?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        if not pendingFallback then return end
        local profile = PM:GetProfile()
        profile.preyLevel = pendingFallback.fallbackIndex
        log("Updated difficulty to", pendingFallback.fallbackName)
        if PM.levelDropdown then PM.levelDropdown.Refresh() end
        pendingPayFee = PM:GetProfile().autoPayFee
        PM.session.difficultyCounts[pendingFallback.fallbackIndex] = (PM.session.difficultyCounts[pendingFallback.fallbackIndex] or 0) + 1
        C_GossipInfo.SelectOption(pendingFallback.opt.gossipOptionID)
        pendingFallback = nil
    end,
    OnCancel = function()
        pendingFallback = nil
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CONFIRM")

frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    -- Auto-pay fee confirmation
    if event == "GOSSIP_CONFIRM" then
        if PM.debug then
            print(PM.PREFIX, "--- GOSSIP_CONFIRM ---")
            print(PM.PREFIX, "optionID:", tostring(arg1), "| text:", tostring(arg2), "| cost:", tostring(arg3))
            print(PM.PREFIX, "--- End GOSSIP_CONFIRM ---")
        end
        if pendingPayFee then
            local confirmText = tostring(arg2 or "")
            if confirmText:lower():find("hunt") then
                pendingPayFee = false
                PM.session.autoFeesPaid = PM.session.autoFeesPaid + 1
                log("Auto-paying hunt fee")
                C_GossipInfo.SelectOption(arg1, "", true)
                StaticPopup_Hide("GOSSIP_CONFIRM")
            else
                pendingPayFee = false
                log("GOSSIP_CONFIRM text did not match hunt confirmation, skipping:", confirmText)
            end
        end
        return
    end

    local npcName = UnitName("npc")
    if not npcName then return end

    local options = C_GossipInfo.GetOptions()
    if not options then return end

    -- Debug dump (only when talking to Astalor, to avoid noise from every other NPC)
    if PM.debug and npcName == NPC_NAME then
        local availableQuests = C_GossipInfo.GetAvailableQuests()
        local activeQuests = C_GossipInfo.GetActiveQuests()

        print(PM.PREFIX, "--- GOSSIP_SHOW Debug ---")
        print(PM.PREFIX, "NPC:", npcName)

        if #options > 0 then
            print(PM.PREFIX, "Gossip Options (" .. #options .. "):")
            for i, opt in ipairs(options) do
                print(PM.PREFIX, "  [" .. i .. "] gossipOptionID=" .. (opt.gossipOptionID or "nil")
                    .. " | name=" .. (opt.name or "nil")
                    .. " | icon=" .. tostring(opt.icon or "nil")
                    .. " | status=" .. tostring(opt.status or "nil")
                    .. " | orderIndex=" .. tostring(opt.orderIndex or "nil"))
                if opt.flags then
                    print(PM.PREFIX, "       flags=" .. tostring(opt.flags))
                end
            end
        else
            print(PM.PREFIX, "No gossip options")
        end

        if availableQuests and #availableQuests > 0 then
            print(PM.PREFIX, "Available Quests (" .. #availableQuests .. "):")
            for i, q in ipairs(availableQuests) do
                print(PM.PREFIX, "  [" .. i .. "] questID=" .. (q.questID or "nil") .. " | title=" .. (q.title or "nil"))
            end
        end

        if activeQuests and #activeQuests > 0 then
            print(PM.PREFIX, "Active Quests (" .. #activeQuests .. "):")
            for i, q in ipairs(activeQuests) do
                print(PM.PREFIX, "  [" .. i .. "] questID=" .. (q.questID or "nil") .. " | title=" .. (q.title or "nil"))
            end
        end
        print(PM.PREFIX, "--- End GOSSIP_SHOW ---")
    end

    -- Auto-accept: master toggle + mode
    if npcName ~= NPC_NAME then return end
    local profile = PM:GetProfile()
    if not profile.autoAccept then return end
    local shiftHeld = IsShiftKeyDown()
    local doAutoAccept
    if profile.autoAcceptMode == PM.ACCEPT_CLICK then
        doAutoAccept = not shiftHeld   -- normal click accepts, Shift skips
    else
        doAutoAccept = shiftHeld       -- Shift-click accepts, normal click is manual
    end
    if not doAutoAccept then return end
    log("Auto-accept triggered (mode=" .. tostring(profile.autoAcceptMode) .. ", shift=" .. tostring(shiftHeld) .. ")")

    -- Page 2: select difficulty (if we just clicked the hunt option)
    if pendingDifficulty then
        pendingDifficulty = false
        local desiredLevel = PREY_LEVELS[profile.preyLevel] or "Normal"

        -- Build a set of available difficulty names
        local availableByName = {}
        for _, opt in ipairs(options) do
            availableByName[opt.name] = opt
        end

        -- Exact match — use it
        if availableByName[desiredLevel] then
            local selected = availableByName[desiredLevel]
            log("Auto-selecting difficulty:", desiredLevel,
                "| gossipOptionID=" .. tostring(selected.gossipOptionID),
                "| icon=" .. tostring(selected.icon),
                "| orderIndex=" .. tostring(selected.orderIndex))
            pendingPayFee = profile.autoPayFee
            PM.session.difficultyCounts[profile.preyLevel] = (PM.session.difficultyCounts[profile.preyLevel] or 0) + 1
            C_GossipInfo.SelectOption(selected.gossipOptionID)
            return
        end

        -- Not available — find the best fallback (next level down)
        local fallbackOpt, fallbackName
        for i = profile.preyLevel - 1, 1, -1 do
            local name = PREY_LEVELS[i]
            if availableByName[name] then
                fallbackOpt = availableByName[name]
                fallbackName = name
                break
            end
        end

        if not fallbackOpt then
            log("No difficulty options available")
            return
        end

        -- Store for the popup callback
        pendingFallback = {
            opt = fallbackOpt,
            desiredLevel = desiredLevel,
            fallbackName = fallbackName,
            fallbackIndex = nil,
        }
        for i, name in ipairs(PREY_LEVELS) do
            if name == fallbackName then
                pendingFallback.fallbackIndex = i
                break
            end
        end

        StaticPopup_Show("PREYMATE_DIFFICULTY_UNAVAILABLE", pendingFallback.desiredLevel, pendingFallback.fallbackName)
        return
    end

    -- Page 1: click the hunt option
    for _, opt in ipairs(options) do
        if opt.gossipOptionID == GOSSIP_OPTION_ID then
            log("Auto-accepting Prey hunt from", npcName)
            pendingDifficulty = true
            PM.session.autoAccepts = PM.session.autoAccepts + 1
            PM.session.huntStartAnguish = PM:GetAnguish()  -- snapshot before fee is charged
            C_GossipInfo.SelectOption(opt.gossipOptionID)
            return
        end
    end
end)
