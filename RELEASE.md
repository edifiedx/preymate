## [1.1.2] - 2026-03-15

[Full Changelog](https://github.com/edifiedx/preymate/blob/main/CHANGELOG.md)

### Fixed
- Tracker scan no longer overwrites valid cached hunt counts with zeroes when quest line data isn't loaded yet (e.g. on login/reload)
- Hunt turn-in now correctly updates the tracker — auto-complete was clearing the active quest ID before QUEST_REMOVED could fire the post-turn-in scan
- Added retry scan after turn-in for robustness

### Changed
- Reward tracker cap raised from 2 to 4 per difficulty with updated color scale: red (0), orange (1), green (2 — gear cap), cyan (3–4 — past gear cap)
- Extracted rewards tracker into its own module (PreyMate_Tracker.lua) for cleaner separation of concerns