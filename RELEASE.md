## [1.0.0] - 2026-03-12

[Full Changelog](https://github.com/edifiedx/preymate/blob/main/CHANGELOG.md)

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