# PreyMate

A lightweight World of Warcraft addon for the Prey hunt system in Midnight.

## Features

### Hunt Automation
- **Auto-tracking** — Automatically tracks the Prey world quest when you accept a hunt, and retracks the hunt quest once your target has been revealed
- **Auto-accept** — Optionally auto-accepts the Prey hunt from Astalor Bloodsworn at your preferred difficulty (Normal / Hard / Nightmare)
- **Auto-pay** — Optionally auto-pays the hunt fee so you don't have to click through the confirmation
- **Auto-complete** — Automatically opens the reward frame when a hunt is complete
- **Auto-collect** — Automatically selects your preferred reward (Gold, Voidlight Marl, Dawncrest, or Anguish)

### Weekly Rewards Tracker
- **Journey Bonus** — Tracks warband-wide weekly hunt completions toward the 4-hunt Journey Point bonus
- **Per-character item rewards** — Shows which item rewards each character has earned by difficulty (Normal / Hard / Nightmare), capped at 2 per difficulty
- **Color-coded counts** — Red (0), orange (1), green (2) at a glance
- **Multi-character support** — Characters are automatically registered on login; data persists across sessions
- **Drag-to-reorder** — Reorder characters in the tooltip via drag handles in the Rewards Tracker settings page
- **Per-character toggles** — Show/hide individual characters and toggle difficulty columns per character
- **Column header toggles** — Toggle an entire difficulty on or off for all characters; new characters inherit header settings

### Minimap Button
- **Tooltip overview** — Hover to see trap count, active hunt info, weekly rewards tracker, and Anguish stats
- **Anguish stats** — Current balance, session delta, per-hunt average, and per-hour rate
- **Configurable left-click** — Track Hunt, Open Settings, or Print Stats
- **Right-click quick menu** — Fast access to all major toggles and profile switching

### Settings
- **Full profile system** — Clone, rename, delete, and switch profiles
- **Rewards Tracker sub-page** — Manage character visibility, difficulty columns, and display order
- **Scrollable settings panel** — All options accessible regardless of panel height

## Slash Commands

- `/pm` — Open the settings panel
- `/pm track` — Manually find and supertrack the active Prey world quest
