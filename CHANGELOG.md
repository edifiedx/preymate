# Changelog

## [0.2.0]
### 2026-03-09
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

## [0.1.0]
### 2026-03-08
### Added
- Automatically tracks the Prey world quest when a hunt quest is accepted
- Retracks the hunt quest when your target has been revealed
- `/pm track` slash command to manually find and supertrack the active Prey world quest
