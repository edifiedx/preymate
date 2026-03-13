## [1.1.0] - 2026-03-13

[Full Changelog](https://github.com/edifiedx/preymate/blob/main/CHANGELOG.md)

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