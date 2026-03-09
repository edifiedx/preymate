# Changelog

## [0.3.3]
### 2026-03-09
### Added
- CurseForge project description auto-updates from README on release

## [0.3.2]
### 2026-03-09
### Fixed
- Removed invalid key from .pkgmeta causing CurseForge packaging errors

## [0.3.1]
### 2026-03-09
### Fixed
- Release workflow now tags the correct commit (includes .toc version update)

## [0.3.0]
### 2026-03-09
### Added
- Auto-pay hunt fee option (confirms gossip cost automatically during auto-accept flow)
- Debug logging for gossip confirm events and difficulty selection details

### Changed
- Reordered settings: Auto-accept, Prey Level, Auto-pay, Debug
- Debug logging label styled grey to reduce visual prominence

## [0.2.1]
### 2026-03-09
### Fixed
- Corrected game version tag from 12.0.0 to 12.0.1
- Added CurseForge project ID to packaging metadata

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
