# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.1.0] - 2026-03-13
### Added
- Weekly Rewards Tracker: minimap tooltip now shows Journey Bonus progress (warband-wide, 4 hunts for 1000 JP) and per-character item rewards by difficulty
- Per-character item reward counts color-coded: red (0/2), orange (1/2), green (2/2)
- Rewards Tracker settings sub-page for managing which characters and difficulties appear in the tooltip
- Drag-to-reorder characters in the Rewards Tracker settings page
- Column header checkboxes toggle an entire difficulty on or off for all characters and set the default for new characters
- Grey mixed-state check on column headers when the default is off but individual characters have it re-enabled
- Characters automatically registered on login with configurable default difficulty visibility
- Tooltip columns use fixed-width spacing so difficulties stay aligned when some are hidden
- Hunt completion now refreshes the weekly tracker scan after quest turn-in
- Clear button per character in Rewards Tracker to remove saved hunt data
- Tooltips on column header checkboxes and Clear button explaining their behavior

## [1.0.1] - 2026-03-12
### Added
- Minimap tooltip now shows the active hunt type (Kill Enemies, Deactivate Shrines, or Chase)

## [1.0.0] - 2026-03-12
### Added
- Full named profile system: clone, rename, delete, and switch profiles from the top of the settings panel
- Clone auto-names the new profile after the current character-realm
- Deleting the last remaining profile is blocked; "Default" can be deleted if another profile exists
- Restore Defaults (Reset) button resets the active profile to factory settings
- Minimap button powered by LibDBIcon-1.0 — shows current hunt info and Anguish stats on hover
- Minimap tooltip shows trap count (item 255825, color-coded by quantity), active hunt level and reward, and Anguish stats
- Anguish stats in minimap tooltip: current balance, session delta, per-hunt average, and per-hour rate
- Stats visibility is individually toggleable per-profile via new Stats Tracking section in settings
- Configurable left-click action for the minimap button: Track Hunt, Open Settings, or Print Stats
- Right-click quick menu on the minimap button for fast access to all major toggles and profile switching
- Session stats now survive `/reload` — if you reload within 5 minutes the current session seamlessly continues
- Settings panel now scrolls, so all options are always accessible regardless of panel height

### Changed
- Settings panel reorganized with named section headers: Auto Accept, Auto Complete, Minimap, Stats Tracking
- Default left-click action is Track Hunt
- Auto-complete is now enabled by default
- Default auto-collect reward changed from Gold to Dawncrest
- Per-hour rate stat is hidden by default (can be enabled in Stats Tracking)

### Fixed
- Rename popup EditBox now correctly applies the new name when pressing Enter

## [0.7.0] - 2026-03-11
### Added
- Tooltips on all settings panel checkboxes explaining what each option does

### Changed
- Auto-accept redesigned: the checkbox is now a master toggle; a new "Click behavior" dropdown lets you choose whether holding Shift triggers or skips auto-accept
- Settings panel reorganized: Auto Accept options grouped into a dedicated section with Hunt Level and Click behavior dropdowns displayed side by side
- Reward option renamed from "Marl" to "Voidlight Marl" to match the in-game currency name

### Fixed
- Gossip debug output now only fires when interacting with Astalor Bloodsworn, not all NPCs

## [0.6.0] - 2026-03-10
### Added
- Auto-complete hunt quest: automatically opens the reward frame when the hunt is complete
- Auto-collect reward: automatically selects your preferred reward (Gold, Marl, Dawncrest, or Anguish) after completing the quest
- Auto-complete and auto-collect settings added to the options panel
- Login/reload recovery now triggers auto-complete and auto-collect if the hunt was already finished before the reload

## [0.5.0] - 2026-03-10
### Changed
- Hunt tracking now uses `C_QuestLog.GetActivePreyQuest()` instead of a hardcoded quest ID list, making detection more robust and future-proof
- `QUEST_LOG_UPDATE` handler optimized to exit immediately when no hunt is active, eliminating unnecessary work on every quest log event

### Fixed
- Tracking now correctly resumes on login or reload if a hunt quest is already active — handles both pre-reveal and post-reveal states

## [0.4.0] - 2026-03-09
### Added
- Hold Shift when clicking Astalor to bypass auto-accept
- Shift-click hint text next to auto-accept checkbox in settings
- Visual separator between main settings and debug option

## [0.3.4] - 2026-03-09
### Fixed
- `/pm` slash command now correctly opens the settings panel

### Removed
- Non-functional CurseForge description update step from release workflow

## [0.3.3] - 2026-03-09
### Added
- CurseForge project description auto-updates from README on release

## [0.3.2] - 2026-03-09
### Fixed
- Removed invalid key from .pkgmeta causing CurseForge packaging errors

## [0.3.1] - 2026-03-09
### Fixed
- Release workflow now tags the correct commit (includes .toc version update)

## [0.3.0] - 2026-03-09
### Added
- Auto-pay hunt fee option (confirms gossip cost automatically during auto-accept flow)
- Debug logging for gossip confirm events and difficulty selection details

### Changed
- Reordered settings: Auto-accept, Prey Level, Auto-pay, Debug
- Debug logging label styled grey to reduce visual prominence

## [0.2.1] - 2026-03-09
### Fixed
- Corrected game version tag from 12.0.0 to 12.0.1
- Added CurseForge project ID to packaging metadata

## [0.2.0] - 2026-03-09
### Added
- Settings panel in Options (ESC > Options > AddOns > PreyMate)
- Auto-accept Prey hunt from Astalor Bloodsworn (toggle in settings)
- Prey difficulty selection (Normal / Hard / Nightmare)
- Fallback popup when selected difficulty is unavailable
- Debug logging toggle in settings
- Addon icon in the AddOns menu
- `/pm` opens settings panel
- Modular file structure (Core, Accept, Options)

### Changed
- Brightened "Prey" color from dark red to #CC3333 for readability
- Quest tracking now retries automatically if super-track doesn't stick
- Slash command callout displayed in a bordered box in settings

### Fixed
- Race condition where quest tracking would report success but not actually track

## [0.1.0] - 2026-03-08
### Added
- Automatically tracks the Prey world quest when a hunt quest is accepted
- Retracks the hunt quest when your target has been revealed
- `/pm track` slash command to manually find and supertrack the active Prey world quest
