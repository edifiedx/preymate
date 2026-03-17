## [1.1.3] - 2026-03-17

[Full Changelog](https://github.com/edifiedx/preymate/blob/main/CHANGELOG.md)

### Fixed
- Weekly reset detection no longer crashes when `GetSecondsUntilWeeklyReset()` isn't available yet at login — this was breaking auto-track, auto-complete, and hunt resume
- Characters that haven't logged in since reset now show zeroed counts in the tooltip instead of disappearing

### Added
- Automatic weekly reset detection: first character to log in after reset clears all stale tracker data across the warband