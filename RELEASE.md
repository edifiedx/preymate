## [1.1.4] - 2026-03-23

[Full Changelog](https://github.com/edifiedx/preymate/blob/main/CHANGELOG.md)

### Fixed
- Tracker scan no longer overwrites cached hunt counts with zeros on fresh login when completion flags haven't loaded yet — retries until flags are available, falls back to cached data if retries are exhausted
- Warband hunt scan (Journey Bonus) now also guards against unloaded quest data instead of returning zeros