# PreyMate — Roadmap & Ideas

Open questions are marked **[?]**. Items are loosely ordered by dependency.

---

## In Progress / Next Up

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

## Auto-Complete Hunt Quest

**Completion flow confirmed:**
- Quest completes in the world after slaying the target — not at an NPC
- Player must click the quest in the log to open the rewards screen (standard WoW reward frame)
- Two quest types behave differently:

**Table quests** (from the hunt board):
- All rewards given automatically, no choice → `GetNumQuestChoices() == 0`
- Auto-complete via `GetQuestReward(0)` — trivial, no config needed

**Random hunts** (from Astalor, the ones auto-accept handles):
- Player picks 1 of 4 reward choices:
  1. Bag of gold (~125g Normal / ~150g Hard)
  2. Voidlight Marl
  3. Remnants of Anguish (50 Normal / 60 Hard)
  4. Dawncrest armor token (Adventurer/Veteran/? Nightmare) — used to upgrade gear
- **[? — verify reward order is consistent across quests and difficulties]**

**Implementation design:**
- Detect choice vs. no-choice via `GetNumQuestChoices()`
- Reward layout is a fixed 2×2 grid (row-major, confirmed):
  ```
  [1] Gold   [2] Marl
  [3] Dawn   [4] Anguish
  ```
  Choice indices are stable — safe to use directly, but still verify via `GetQuestItemInfo("choice", i)` in debug
- Setting: **Preferred reward** — `None` (manual) / `Gold` / `Marl` / `Anguish` / `Dawncrest`
  - Default: `None` (safest; player completes manually)
  - If set: call `GetQuestReward(index)` with the matching index
  - Armor token type (Adventurer vs. Veteran) is implicit from difficulty — no extra setting needed
- Add to `PROFILE_DEFAULTS` as `autoCompleteReward = 0` (0 = manual, 1–4 = index)
- Events to hook for when reward frame opens: likely `QUEST_COMPLETE` **[? — confirm in-game]**

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

## Deferred

- **Auto-complete + auto-retrack on zone change** — keep an eye on it, not a confirmed issue
- **"Skip if not available" difficulty mode** — hard to test (requires locked-out alt); revisit later
