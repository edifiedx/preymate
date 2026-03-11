# PreyMate — Roadmap & Ideas

Open questions are marked **[?]**. Items are loosely ordered by dependency.

---

## Next Up

### Full Named Profile System

> full named profiles, default as the default, and if they want a new one they can clone one. so we'll need a dropdown for profiles that exist. if they clone it should auto name the clone after the character-realm they're on. we'll give them an option to rename profiles and delete them. but we won't let them delete the last profile that exists. they can delete default, as long as their other profile exists. and i want a restore defaults that sets the current profile to all of the defaults.
>
> it would live right at the top of the settings separated by rules.
> profile, clone, delete, rename should cover it. confirmation on the delete.
>
> and just below all of that, a restore defaults button, but have it be less visible than the others.

---

### Currency & Session Stats

**Currencies confirmed:**
- **Remnants of Anguish** (currency ID: `3392`) — primary tracking target
  - **Table hunts**: free to start; 4 per unlocked difficulty per week
  - **Random hunts**: costs **50 Anguish** to start — deducted when auto-pay fires
  - Looted occasionally during the hunt (via `CURRENCY_DISPLAY_UPDATE`)
  - Selectable as quest reward: **50 Normal / 60 Hard** (Nightmare TBD)
  - Tracking goal: net Anguish per session — are you breaking even, profiting, or burning?
    - Break-even baseline (if picking Anguish reward): -50 start + loot drops + 50 reward = just the loot
    - Hard with Anguish reward: -50 + loot + 60 = +10 + loot guaranteed
- **Voidlight Marl** — global cosmetic currency; secondary display candidate (no ID yet **[?]**)
- **Gold** — bag reward (~125g Normal / ~150g Hard); not tracked

**Tracking approach:**
- Use `CURRENCY_DISPLAY_UPDATE` event — fires on any currency change (loot, reward, spend)
- Snapshot Anguish at session start (`PLAYER_ENTERING_WORLD`), store in session-only state (not saved)
- Delta = current amount − snapshot
- Rate/hr = delta / elapsed time since session start
- The -50 spend at hunt start will naturally appear in the delta via `CURRENCY_DISPLAY_UPDATE`
  (no need to hook the gossip flow separately)
- `C_CurrencyInfo.GetCurrencyInfo(3392)` returns `.quantity` for current amount

**Display:** Minimap tooltip will show current Anguish on hand, session delta (+/-), rate/hr

---

### Minimap Button

**Library decision: native** — zero dependencies, fully self-contained. Position angle saved to `PreyMateDB.minimapAngle`. Draggable by default.

**Interactions:**
- **Left click** → manual track (same as `/pm track`)
- **Shift+Left click** → open Settings panel
- **Right click** → context dropdown:
  - Toggle Auto-Accept on/off
  - Toggle Auto-Pay Fee on/off
  - Set Prey difficulty (Normal / Hard / Nightmare)

**Hover tooltip displays:**
- Remnants of Anguish: current quantity + session delta (+/-) + rate/hr
- Voidlight Marl: current quantity (secondary, optional, pending Marl currency ID)

**Implementation notes:**
- Use `GameTooltip` with `:SetOwner(button, "ANCHOR_LEFT")` for hover display
- Right-click menu via `EasyMenu` / `UIDropDownMenu` (same pattern as existing dropdown in Options)
- Angle persistence: save/load `PreyMateDB.minimapAngle`, default to 45°
- New file: `PreyMate_Minimap.lua` (added to `.toc` after Options)

---

## Backlog

### Profile System

See Next Up for full spec.

### Module Restructure

- Extract quest tracking logic from `PreyMate.lua` into `PreyMate_Track.lua`
- `PreyMate.lua` becomes pure meta/core: global table, profile system, slash commands, ADDON_LOADED
- Centralize `PREY_LEVELS` and other shared constants into `PM` (currently duplicated in Accept + Options)
- Update `.toc` load order accordingly

### Settings Panel Modernization

- Experiment with new WoW Settings API widgets (replace `InterfaceOptionsCheckButtonTemplate`, `UIDropDownMenuTemplate`)
- Verify they work correctly in retail 12.x before committing
- Keep layout manual via `yOff` pattern unless new API offers better layout primitives

### Log Levels / Gossip Debug Noise

- Current `debug` toggle is all-or-nothing — turns on verbose gossip dumps that fire on every NPC interaction, not just Astalor
- Look at introducing log levels (e.g. `VERBOSE` vs `DEBUG`) so gossip dumps are opt-in at a higher level
- At minimum, guard the full GOSSIP_SHOW dump to only fire when talking to Astalor (check `npcName == NPC_NAME` before printing)
- Consider a separate "Verbose gossip logging" checkbox, or just gate the dump on `npcName == NPC_NAME`

### Shift-Click Auto-Accept

- Shift+click on Astalor **always** triggers auto-accept — no setting required
- "Auto-accept" checkbox enables auto-accept on **normal click** too (removes the Shift requirement)
- Rename checkbox label to something like `"Auto-accept on click"` with hint text `"(Shift always auto-accepts)"`
- No `shiftInvert` flag needed — logic simplifies to: `local doAutoAccept = IsShiftKeyDown() or profile.autoAccept`
- Remove existing shift hint text; replace with the always-on Shift note

### CurseForge Changelog Trimming

- CurseForge displays the entire history on every release — gets long over time
- **Idea:** Add a separate `CHANGELOG_CURSEFORGE.md` with only the last few versions + link to full GitHub changelog
- Update `.pkgmeta` `manual-changelog` to point at the new file
- **[? — auto-generated by CI from top N entries, or maintained manually?]**

---

## Deferred

- **Auto-complete + auto-retrack on zone change** — keep an eye on it, not a confirmed issue
- **"Skip if not available" difficulty mode** — hard to test (requires locked-out alt); revisit later

---

## Confirmed APIs & Findings

- `C_QuestLog.GetActivePreyQuest()` → returns active hunt quest ID (works at `PLAYER_ENTERING_WORLD` and after)
- `C_CurrencyInfo.GetCurrencyInfo(3392)` → Remnants of Anguish (confirmed ID, no cap)
- Widget `7663` → prey reveal progress widget (progressState, tooltip text, textureKit) — pre-hunt reveal phase only, not combat HP
- `ShowQuestComplete(questID)` + `C_Timer.After(AUTOCOLLECT_DELAY)` + `GetQuestReward(index)` → confirmed auto-complete flow
- `GetNumQuestChoices()` → 0 for table quests, 4 for random hunts
- Reward grid (2×2, row-major, confirmed): Gold=1, Marl=2, Dawncrest=3, Anguish=4
- Quest line ID `5945` identifies Prey hunt quests via `C_QuestLine.GetQuestLineQuests()`


### Performance: `QUEST_LOG_UPDATE` optimization
- Cache `C_QuestLine.GetQuestLineQuests(5945)` at load time into `PM.preyQuestLineIDs`
- Add `PM.activeHuntQuestID = nil`; populate on `QUEST_ACCEPTED`, clear when target is revealed
- Handler becomes a O(1) nil-check early exit when not on a hunt — no iteration, no API calls
- **Status:** Implemented — needs in-game test

### APIs to probe in-game
Run these in the console to verify availability and return values:
```lua
-- May replace the preyWorldQuestIDs table and FindAndTrackPreyWorldQuest logic entirely
/run print(C_QuestLog.GetActivePreyQuest())

-- Hunt health/progress widget — may power a progress bar during active hunts
-- widgetID unknown; scan with C_UIWidgetManager.GetAllWidgetsBySetID() or check UIParent widgets
/run print(C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(?))

-- Verify Anguish currency ID and current quantity
/run local i = C_CurrencyInfo.GetCurrencyInfo(3392); if i then print(i.name, i.quantity) end

-- Probe reward track (Prey progression system, similar to Delves)
/run print(C_DelvesUI.GetDelvesSeasonData())  -- may or may not include Prey data
```

**`C_QuestLog.GetActivePreyQuest()` implications:**
- If it returns the active hunt quest ID, it could replace the entire `preyHuntQuestIDSet` lookup
- Could also replace `FindAndTrackPreyWorldQuest()` — just call this and super-track the result
- May only return the Astalor random hunt quest, not table quests — TBD

**`C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo()` implications:**
- Likely tracks target health/vulnerability during the hunt (the red glow mechanic)
- Could drive a proper progress bar widget instead of relying on the world object visual
- widgetID needs discovery — try scanning `C_UIWidgetManager.GetAllWidgetsBySetID()` or checking existing widget frames

---

## Currency & Session Stats

**Currencies confirmed:**
- **Remnants of Anguish** (currency ID: `3392`) — primary tracking target
  - **Table hunts**: free to start; 4 per unlocked difficulty per week
  - **Random hunts**: costs **50 Anguish** to start — deducted when auto-pay fires
  - Looted occasionally during the hunt (via `CURRENCY_DISPLAY_UPDATE`)
  - Selectable as quest reward: **50 Normal / 60 Hard** (Nightmare TBD)
  - Tracking goal: net Anguish per session — are you breaking even, profiting, or burning?
    - Break-even baseline (if picking Anguish reward): -50 start + loot drops + 50 reward = just the loot
    - Hard with Anguish reward: -50 + loot + 60 = +10 + loot guaranteed
- **Voidlight Marl** — global cosmetic currency; secondary display candidate (no ID yet **[?]**)  
- **Gold** — bag reward (~125g Normal / ~150g Hard); not tracked

**Tracking approach:**
- Use `CURRENCY_DISPLAY_UPDATE` event — fires on any currency change (loot, reward, spend)
- Snapshot Anguish at session start (`ADDON_LOADED`), store in session-only state (not saved)
- Delta = current amount − snapshot
- Rate/hr = delta / elapsed time since session start
- The -50 spend at hunt start will naturally appear in the delta via `CURRENCY_DISPLAY_UPDATE`
  (no need to hook the gossip flow separately)
- `C_CurrencyInfo.GetCurrencyInfo(3392)` returns `.quantity` for current amount

**Reward track:** Not a separate system — Remnants are spent freely, no formal track
  - Minimap tooltip will show: current Anguish on hand, session delta (+/-), rate/hr
  - Voidlight Marl on hand as secondary line (optional)

---

## Minimap Button

**Library decision: native vs. LibDBIcon**
- **LibDBIcon-1.0** (the popular one): requires LibStub + a DataBroker object. Gives free position
  memory, draggable around the minimap edge, automatic conflict-avoidance with other buttons.
  Means bundling two libraries (~10KB) and wiring up DataBroker callbacks.
- **Native** (`CreateFrame("Button", nil, Minimap)`): zero dependencies, fully self-contained,
  manually handle dragging + angle persistence in `PreyMateDB`. A bit more code but nothing complex.
- **Recommendation:** Native. PreyMate has no other library dependencies and the native approach
  is well-understood. Position angle saved to `PreyMateDB.minimapAngle`. Draggable by default.
  Can always wrap in LibDBIcon later if users request it.

**Interactions:**
- **Left click** → manual track (same as `/pm track`)
- **Shift+Left click** → open Settings panel
- **Right click** → context dropdown:
  - Toggle Auto-Accept on/off
  - Toggle Auto-Pay Fee on/off
  - Set Prey difficulty (Normal / Hard / Nightmare)

**Hover tooltip displays:**
- Prey progression track: tier + progress **[? — pending API discovery]**
- Remnants of Anguish: current quantity + session delta (+/-) + rate/hr
- Voidlight Marl: current quantity (secondary, optional)

**Implementation notes:**
- Use `GameTooltip` with `:SetOwner(button, "ANCHOR_LEFT")` for hover display
- Right-click menu via `EasyMenu` / `UIDropDownMenu` (same pattern as existing dropdown in Options)
- Angle persistence: save/load `PreyMateDB.minimapAngle`, default to 45°
- New file: `PreyMate_Minimap.lua` (added to `.toc` after Options)

---

## Per-Character Difficulty & Profile System Redesign

- Current system: named profiles with character → profile mapping
- **[? — outline desired profile UX before building]**
  - Per-character defaults vs. named sharable profiles?
  - What settings are character-scoped vs. account-scoped?
  - UI for creating/switching/deleting profiles?
- Move difficulty preference to character scope at minimum
- Profile dropdown in options panel to expose the existing but UI-less profile system

---

## Module Restructure

- Extract quest tracking logic from `PreyMate.lua` into `PreyMate_Track.lua`
- `PreyMate.lua` becomes pure meta/core: global table, profile system, slash commands, ADDON_LOADED
- Centralize `PREY_LEVELS` and other shared constants into `PM` (currently duplicated in Accept + Options)
- Update `.toc` load order accordingly

---

## Settings Panel Modernization

- Experiment with new WoW Settings API widgets (replace `InterfaceOptionsCheckButtonTemplate`, `UIDropDownMenuTemplate`)
- Verify they work correctly in retail 12.x before committing
- Keep layout manual via `yOff` pattern unless new API offers better layout primitives

---

## Shift-Click Auto-Accept

**Design:** Shift+click on Astalor is always an auto-accept shortcut, regardless of settings. The `autoAccept` setting now controls whether a **normal** click also auto-accepts — removing the need to hold Shift.

**Behavior:**
- Shift+click Astalor → auto-accept (always, no setting needed)
- Normal click, `autoAccept = false` → opens gossip manually (default)
- Normal click, `autoAccept = true` → auto-accepts without Shift

**Implementation:**
- `PROFILE_DEFAULTS`: no new key needed — `autoAccept` meaning shifts to "skip Shift requirement"
- Logic in `PreyMate_Accept.lua` GOSSIP_SHOW handler:
  ```lua
  local doAutoAccept = IsShiftKeyDown() or profile.autoAccept
  if not doAutoAccept then return end
  ```
- Options panel:
  - Checkbox label: `"Auto-accept on click"`
  - Remove the old `(hold Shift to bypass)` hint
  - Add a static note below or inline: `"(Shift-click always auto-accepts)"`

---

## CurseForge Changelog

- Currently ships the full `CHANGELOG.md` via `.pkgmeta` `manual-changelog`
- CurseForge displays the entire history on every release — gets long over time
- **Idea:** Add a separate `CHANGELOG_CURSEFORGE.md` that contains only the last few versions + a link back to the full changelog on GitHub
- Update `.pkgmeta` to point `manual-changelog` at the new file
- CI would need a step to auto-populate it from the latest N entries (or maintain it manually)
- **[? — decide: auto-generated by CI from top N entries, or maintained manually?]**

---

## Settings Update Splash

**Goal:** When new settings are added to PreyMate, show a one-time popup on login asking the player if they want to open the settings panel to check them out.

**Version tracking:**
- Add `local CONFIG_VERSION = 1` constant in `PreyMate.lua` — bump this integer whenever new user-facing settings are added
- Store `PreyMateDB.lastSeenConfigVersion` (account-wide, not per-character) in the saved variable
- On `ADDON_LOADED`, after profile init: if `lastSeenConfigVersion < CONFIG_VERSION`, queue the splash

**Splash timing:**
- Fire after `PLAYER_ENTERING_WORLD` (not at ADDON_LOADED) so the UI is fully ready
- Use a `StaticPopupDialogs` dialog for the prompt

**Dialog design:**
```lua
StaticPopupDialogs["PREYMATE_SETTINGS_UPDATED"] = {
    text = "|cffcc3333Prey|rMate has new settings!\n\nWould you like to open the settings panel?",
    button1 = "Open Settings",
    button2 = "Later",
    OnAccept = function()
        PreyMateDB.lastSeenConfigVersion = CONFIG_VERSION
        Settings.OpenToCategory(PM.settingsCategory.ID)
    end,
    OnCancel = function()
        -- Don't update version — show again next login until they open settings
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
```
- "Later" does **not** advance `lastSeenConfigVersion` — splash reappears next login until they click "Open Settings"
- **[? — or should "Later" permanently dismiss for this version? Decide UX.]**

**What bumps `CONFIG_VERSION`:**
- New checkboxes or dropdowns added to the options panel
- Existing settings that changed behavior significantly
- Does **not** bump for: bug fixes, internal refactors, new features with no settings
