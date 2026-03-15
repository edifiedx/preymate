# PreyMate — Copilot Instructions

## Project Overview

PreyMate is a World of Warcraft retail addon for the Prey hunt system in The War Within: Midnight expansion. It auto-tracks Prey world quests, auto-accepts hunts from an NPC, and auto-pays the hunt fee.

- **GitHub**: https://github.com/edifiedx/preymate
- **CurseForge Project ID**: 1481436
- **Game Client**: WoW Retail (Interface 120001 = patch 12.0.1)
- **Language**: Lua (WoW API)
- **Workspace**: Lives in the WoW AddOns directory, not a standalone repo root

## Architecture

### Shared Addon Table Pattern

All modules share state through a global table:

```lua
-- PreyMate.lua (core) creates the table
PreyMate = {}

-- Every other file references it locally
local PM = PreyMate
```

Never create a second global. Attach shared state (functions, flags, references) to `PM`.

### File Structure

| File | Purpose |
|---|---|
| `PreyMate.lua` | Core — shared table, profile system, quest tracking, events, slash commands |
| `PreyMate_Accept.lua` | Auto-accept & auto-pay — gossip event handling for Astalor Bloodsworn |
| `PreyMate_Minimap.lua` | Minimap button (LibDBIcon), tooltip rendering, context menu |
| `PreyMate_Tracker.lua` | Rewards tracker — warband/character scan, tracker tooltip section, tracker settings sub-page |
| `PreyMate_Options.lua` | Settings panel — UI construction, registered via `Settings.RegisterCanvasLayoutCategory` |
| `PreyMate.toc` | Addon manifest — **version is auto-updated by CI, do not manually edit the Version field** |
| `.pkgmeta` | CurseForge packaging config |
| `CHANGELOG.md` | Drives the release workflow — adding a new `## [x.y.z]` entry triggers a release |
| `.github/workflows/release.yml` | CI/CD — version extraction, .toc update, tagging, GitHub release creation |

### Load Order (defined in .toc)

1. `PreyMate.lua` — must be first (creates the global table and profile system)
2. `PreyMate_Accept.lua` — depends on `PreyMate` table existing
3. `PreyMate_Minimap.lua` — minimap button, tooltip, context menu
4. `PreyMate_Tracker.lua` — rewards tracker module (scan, tooltip section, settings sub-page)
5. `PreyMate_Options.lua` — depends on `PreyMate` table and calls `PM:InitSettings()`

## Coding Conventions

### Lua Style

- Use `local` for everything except the one global `PreyMate = {}`
- Module-level constants at the top of each file (e.g., `local NPC_NAME = "Astalor Bloodsworn"`)
- **No magic numbers** — every numeric literal with non-obvious meaning must be a named `local` constant at the top of the file; this includes delays, IDs, indices, and thresholds
- Debug logging via a local `log(...)` function that checks `PM.debug` or a local `DEBUG` flag
- Debug log output uses `PM.PREFIX` (`[PreyMate]` with colored text) as the first argument to `print()`
- Use WoW color escapes for UI text: `|cffRRGGBB...|r`
- Addon prefix color is `|cffcc3333` (red) for "Prey", white for "Mate"

### Profile System

- Saved variable: `PreyMateDB` (declared in .toc as `SavedVariables`)
- Structure: `PreyMateDB.profiles["Default"] = { ... }` and `PreyMateDB.characterProfiles["Name - Realm"] = "Default"`
- New settings must be added to `PM.PROFILE_DEFAULTS` in PreyMate.lua — the ADDON_LOADED handler backfills missing keys
- Always access current settings via `PM:GetProfile()`, never cache the profile table long-term

### Settings Panel (Options)

- Uses legacy `InterfaceOptionsCheckButtonTemplate` and `UIDropDownMenuTemplate` (still works in retail)
- Helper functions: `CreateCheckbox()`, `CreateDropdown()`, `CreateButton()`
- Layout is manual via `yOff` counter (no automatic layout)
- Category is stored as `PM.settingsCategory` for slash command access
- Debug checkbox text is grey (`SetTextColor(0.5, 0.5, 0.5)`) and separated from main options by an HR

### Event Handling

- Each module creates its own `CreateFrame("Frame")` for event registration
- Gossip flow uses pending flags (`pendingDifficulty`, `pendingFallback`, `pendingPayFee`) to track multi-step NPC interaction state
- Safety checks: GOSSIP_CONFIRM auto-pay requires both `pendingPayFee == true` AND confirmation text containing "hunt"
- `IsShiftKeyDown()` bypasses auto-accept when holding Shift

### Slash Commands

- `/pm` — opens settings (registered as `SLASH_PREYMATE1`). Note: this conflicts with WoW's `/pm` for private messages but works because the addon overrides it after load.
- `/pm track` — manually triggers world quest tracking

## Release Workflow

### How Releases Work

1. Add a new `## [x.y.z] - YYYY-MM-DD` section at the top of `CHANGELOG.md` (below `## [Unreleased]`)
2. Commit locally, then `git pull --rebase` before pushing — CI commits a .toc update after each release, so the remote is often ahead
3. Push to `main`
4. The workflow detects the new version, updates `.toc` Version field, creates an annotated tag and GitHub release
5. CurseForge webhook (`Releases` event type) picks up the release automatically

### CHANGELOG Format

```markdown
## [x.y.z] - YYYY-MM-DD
### Added/Changed/Fixed/Removed
- Description of change
```

### Important CI/CD Details

- **Do NOT manually edit the `## Version:` line in the .toc** — the workflow handles this
- The workflow has 3 jobs: `process-version` → `update-files` → `create-release`
- `create-release` does a `git pull` before tagging to ensure it includes the .toc update commit
- Releases created by `GITHUB_TOKEN` do NOT trigger GitHub webhooks (known GitHub limitation).
- CurseForge webhook is configured on **"Branch or tag creation"** (not "Releases") — the tag push fires exactly once, avoiding duplicate CurseForge builds. Branch creation events will also fire the webhook; any spurious branch builds should be manually deleted on CurseForge.
- Git user for CI commits: `github-actions[bot]` with noreply email

### CurseForge

- Webhook URL: configured in GitHub repo settings under Webhooks, event type "Releases"
- `.pkgmeta` must NOT contain `curseforge-id` — that key is only for BigWigs packager, not CurseForge's built-in packager
- CurseForge Upload API does NOT have a project description update endpoint — descriptions must be edited on the website
- The `manual-changelog` key in `.pkgmeta` points CurseForge to use `CHANGELOG.md`

## Known Quirks

- WoW quest data may not be immediately available after accepting a quest — the addon retries up to 4 times with increasing delays (1s, 2s, 3s, 4s)
- `C_SuperTrack.SetSuperTrackedQuestID()` sometimes doesn't "stick" on first call — retry logic handles this
- `Settings.OpenToCategory()` requires the category ID from the registered category object, not just the addon name string
- Gossip interactions are multi-page: Page 1 has the hunt option (gossipOptionID 134357), Page 2 has difficulty selection. The `pendingDifficulty` flag bridges these two GOSSIP_SHOW events.
- Quest line ID `5945` is used to identify Prey hunt quests via `C_QuestLine.GetQuestLineQuests()`
