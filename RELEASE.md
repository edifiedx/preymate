## [1.1.5] - 2026-03-24

[Full Changelog](https://github.com/edifiedx/preymate/blob/main/CHANGELOG.md)

### Changed
- Adapted to recent Prey hotfix: Journey Ranks 1-3 now award full 1000 progress on every hunt (not just the first 4), while Rank 4+ retains the first-4 weekly bonus
- Journey Bonus tracker is now rank-aware using the Major Factions API (faction 2764, Prey: Season 1)
- Ranks 1-3: tooltip shows "Rank 4 in: X hunts" since all hunts award full progress at these ranks
- Rank 4+: tooltip shows "Journey Bonus: X/4" tracking the first 4 weekly hunts that award 1000 (rest award 50)
- Tooltip now always shows "Journey Rank: X (earned/threshold)" with current rank and progress into the next rank

### Added
- `/pm journey` debug command to print current Journey rank and progress
- `/pm fakerank <rank> <earned>` debug command to preview the tooltip at any rank (useful for testing)