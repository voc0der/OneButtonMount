## [Unreleased]

## [1.0.31] - 2026-08-08

### Fixed
- Detected the Black Qiraji Resonating Crystal as a mount; TBC-era clients do not tag Qiraji crystals with the Miscellaneous/Mount item class, so the bag scan skipped them entirely
- Treated the black crystal as usable everywhere rather than AQ40-only, since it is the one crystal that works outside the Temple of Ahn'Qiraj
- Kept the black crystal eligible inside AQ40 alongside the colored crystals
- Marked the AQ40-only Qiraji crystals as ground-only so they can no longer be added to the flying rotation. The black crystal is deliberately left unclassified so it behaves like every other mount; TBC-era clients report no mount type for anything else, so classifying it would have made it the only mount in the game that could not be added to the flying rotation
- Explained the ground-only refusal instead of just stating it, and stopped the available-mounts tooltip offering a flying-pool click that would be refused
- Resolved item and spellbook APIs through `C_Item` and `C_SpellBook`, falling back to the bare globals for older clients. TBC Anniversary only defines `GetItemSpell`, `GetItemInfo`, `GetItemInfoInstant`, `GetItemSubClassInfo`, `UseItemByName`, `IsSpellKnown`, and `IsPlayerSpell` while the client's `loadDeprecationFallbacks` CVar is on; with it off the bag-item mount scan was skipped entirely and no item mount could be summoned
- Wrapped rotation icons onto additional rows; past ten mounts in a rotation the extra icons were drawn on top of the first row and could not be seen or removed
- Stopped a rotation that exactly fills its last row from reserving an empty row beneath it, which wasted vertical space and squeezed the available mounts list

### Changed
- Both rotation rows and the available mounts list now share one icon grid helper and one wrapping rule, instead of three separate copies of the layout maths

### Added
- Added a checkbox beside the `Flying Mount Rotation` header that switches the flying rotation off, so you can stay on ground mounts where you could otherwise fly (for example to match a group that has not unlocked flying yet). Enabled by default and remembered per character
- Regression coverage that runs mount detection and summoning with the deprecated globals removed, so both the namespaced and legacy API paths are exercised

## [1.0.30] - 2026-07-07

### Changed
- Updated the TBC Anniversary TOC interface to `20506` to match the client's move to game version `2.5.6`

## [1.0.29] - 2026-07-07

### Fixed
- Stopped re-sanitizing saved ground/flying mount pools on every loading screen (`PLAYER_ENTERING_WORLD`); the TBC Anniversary maintenance patch made the mount collection scan unreliable immediately after zoning, so a saved pick could be pruned as "unknown" if it was transiently missing from that scan. Saved pools are now only sanitized on addon load and on `COMPANION_UPDATE` (when the mount collection actually changes)
- Added regression coverage for a loading screen where the mount scan briefly omits already-saved mounts

## [1.0.28] - 2026-05-18

### Added
- Added movement-aware instant mount selection so eligible instant options like Druid Flight Form and Hallow's End brooms are preferred while moving
- Added Druid Flight Form and Swift Flight Form to the spell-only flying mount candidates
- Added regression coverage for moving instant-mount selection and stationary cast-time mount preference

## [1.0.27] - 2026-05-17

### Changed
- Updated the TBC Anniversary TOC interface to `20505` so CurseForge release tagging targets game version `2.5.5`.

## [1.0.26] - 2026-05-17

### Changed
- Replaced the Crusader Aura "Raids" disable context with "Dungeons"; "PvP and Dungeons" now suppresses Crusader Aura in battlegrounds, arenas, and dungeon instances
- Migrated the short-lived saved `raid` disable mode from `1.0.25` to the new dungeon mode
- Added regression coverage for Black Morass-style dungeon suppression, PvP arena/battleground suppression, and raids no longer being suppressed by dungeon mode

## [1.0.25] - 2026-05-14

### Added
- Added a Paladin-only Crusader Aura context dropdown that can disable "Crusader Aura on Mount" in PvP, raids, both, or neither
- Added regression coverage for the dropdown selection and PvP/raid suppression behavior

## [1.0.24] - 2026-04-16

### Added
- Added opt-in "Crusader Aura on Mount" checkbox to the config UI, visible only for Paladins who know Crusader Aura (spell 32223); unchecked by default
- When enabled, the first button press switches to Crusader Aura (if not already active); the second press mounts — avoiding the GCD conflict that caused "spell is not ready" on Paladin class mounts
- Cancelling the mount cast (`UNIT_SPELLCAST_INTERRUPTED`) automatically restores the previous aura and deactivates Crusader Aura
- Previously active paladin aura is restored after any dismount, including accidental dismounts detected via `UNIT_AURA`

## [1.0.23] - 2026-04-11

### Fixed
- Added mouse wheel capture to the keybind overlay so `MOUSEWHEELUP`, `MOUSEWHEELDOWN`, and modifier chords such as `SHIFT-MOUSEWHEELUP` can be bound from the config UI
- Added regression coverage for `Shift + Mouse Wheel Up` and `Shift + Mouse Wheel Down` binding capture

## [1.0.22] - 2026-04-06

### Fixed
- Resolved blood elf paladin class mounts to their learned spell IDs so Thalassian Warhorse and Thalassian Charger work cleanly in both secure and direct summon paths
- Remapped saved paladin class-mount spell IDs to the learned faction variant during pool sanitization so older saved rotations keep working after the update

## [1.0.21] - 2026-03-30

### Fixed
- Removed the broken `/obm mount` summon path from the slash interface entirely so summoning stays on the normal keybind and UI paths

## [1.0.20] - 2026-03-30

### Fixed
- Made `/obm mount` prefer the same macro-style summon path used by the working hotkey flow when the client exposes `RunMacroText()`

## [1.0.19] - 2026-03-30

### Added
- Added `/obm debug` to print a single-line snapshot of the live zone, map, riding, flyable-area, and pool-selection state for troubleshooting

### Fixed
- Added spellbook-based known-spell fallback so paladin and warlock class mounts still appear in the selectable pool on TBC clients where `IsSpellKnown()` does not expose those spells reliably
- Reused the same spellbook fallback for riding-skill checks so flying eligibility no longer depends on a single spell-knowledge API
- Replaced several logic-critical English string checks with spell IDs, localized spell names, localized map metadata, or localized item subtype comparisons so non-English clients no longer depend on raw English game text

## [1.0.18] - 2026-03-30

### Added
- Added paladin and warlock class-mount spells to the selectable mount list so Summon Warhorse, Summon Charger, Summon Felsteed, and Summon Dreadsteed can be saved into mount rotations

### Fixed
- Prevented known flying mounts from being selected when the character cannot currently use flying, even if those mounts were saved in a rotation pool
- Stopped `IsFlyableArea()` from bypassing the character's riding-skill and level checks when deciding whether flying mounts are eligible

## [1.0.17] - 2026-03-29

### Fixed
- Made Outland detection locale-safe by matching live zone text against localized `C_Map` names when available instead of relying on English-only fallback names
- Prevented stale positive `C_Map.GetBestMapForUnit()` results from forcing flying mounts in non-Outland zones when live zone text disagrees with the resolved map hierarchy

## [1.0.16] - 2026-03-27

### Added
- Saved mount rotations, keybinds, minimap settings, config window position, and textual feedback preferences per character

### Changed
- Added one-time migration from the previous account-wide saved settings into each character profile without overwriting characters that already have profile data
- Expanded regression coverage for per-character storage, legacy migration, and per-character UI preferences

## [1.0.15] - 2026-03-27

### Fixed
- Prefer live zone text over stale `GetCurrentMapAreaID()` results so Stormwind and similar non-Outland zones do not incorrectly select flying mounts after visiting Outland
- Added regression coverage to preserve the legacy area-ID fallback when zone text is unavailable while preventing stale Outland context from leaking into city mount selection

## [1.0.14] - 2026-03-26

### Fixed
- Added `## X-Curse-Project-ID: 1484391` to addon metadata so automated CurseForge packaging can upload releases to the correct project

## [1.0.12] - 2026-03-25

### Added
- Added a `Show Textual Feedback` setting next to the minimap toggle in the config UI, enabled by default

### Changed
- Routed addon status and mount-error chat messages through the new feedback setting so they can be muted without affecting explicit `/obm help` output

## [1.0.11] - 2026-03-14

### Fixed
- Limited flying-pool selection to Outland context so false-positive `IsFlyableArea()` results no longer force flying mounts in cities like Orgrimmar
- Added regression coverage to keep Outland flyable cities working while preventing non-Outland flyable-area misclassification

## [1.0.10] - 2026-03-12

### Fixed
- Removed mount icon overlay behavior that could make icons appear as hollow/box-only tiles
- Kept icon edge cropping and replaced the heavy overlay with a lightweight outline so icon artwork remains clearly visible

## [1.0.9] - 2026-03-12

### Fixed
- Refined mount icon rendering to remove the inner-square/checkbox-style artifact in icon slots
- Updated icon border styling for cleaner, more consistent mount tiles

### Changed
- Updated README branding header with repository icon asset and centered project intro

## [1.0.8] - 2026-03-12

### Fixed
- Added AQ40-specific mount rules: inside Temple of Ahn'Qiraj only configured Qiraji crystal mounts are eligible
- Outside AQ40, Qiraji crystal mounts are now excluded from random selection even if present in configured pools
- Unified eligibility filtering between click summon and keybind summon paths so both respect AQ40 crystal rules
- Added regression tests for AQ40 crystal-only selection and non-AQ40 exclusion behavior

## [1.0.7] - 2026-03-12

### Fixed
- `CanFlyHere()` now prefers native `IsFlyableArea()` when available, fixing wrong ground-mount selection in flyable Outland cities such as Shattrath
- Added regression test to ensure flyable-area signal selects the flying pool even when riding spell flags are unreliable

## [1.0.6] - 2026-03-12

### Fixed
- Updated secure bind button registration to support both key-down and key-up click modes
- Switched override binding application to priority mode with explicit `LeftButton` click target for better mouse-chord reliability
- Added regression tests for down/up binding registration and override binding parameters

## [1.0.5] - 2026-03-12

### Fixed
- Added a strict-safe number conversion helper to prevent Classic `tonumber(nil)` startup/runtime failures
- Added companion index probing fallback so mounts still populate when `GetNumCompanions("MOUNT")` returns nil/empty
- Improved companion flying classification when mount type metadata is unavailable, allowing assignment without false rejection
- Hardened bag slot and bag item parsing across mixed Classic container APIs
- Added side-mouse chord capture fallback through `OnMouseDown` for more reliable `SHIFT-BUTTON4/5` binding capture

## [1.0.4] - 2026-03-12

### Fixed
- Added TBC bag-item mount scanning fallback so mount lists populate when companion and journal APIs are unavailable
- Added item-based summon path (`UseItemByName`) for bag-backed mounts
- Updated secure keybind macro generation to use `/use item:<id>` for item-backed mounts
- Improved compatibility across companion, mount journal, and bag-based mount sources

## [1.0.3] - 2026-03-12

### Fixed
- Added `C_MountJournal` mount scanning fallback so mount lists populate on clients where companion APIs are empty
- Added `C_MountJournal.SummonByID` summon path for journal-backed mounts
- Improved keybind capture overlay to reliably capture mouse chords such as `SHIFT-BUTTON5`
- Kept flying pool validation only when mount flying capability can be confidently determined

## [1.0.2] - 2026-03-12

### Fixed
- Handle `GetNumCompanions("MOUNT")` calls that return zero values during early load
- Prevent `tonumber` startup crash by normalizing companion count via a local variable first

## [1.0.1] - 2026-03-12

### Added
- Local regression test coverage for mount scan and keybind edge cases

### Fixed
- Prevent startup error when `GetNumCompanions("MOUNT")` returns nil
- Sanitize saved mount pools to remove stale or invalid mount spell IDs
- Normalize mouse keybind tokens (for example `RightButton` -> `BUTTON2`)
- Add flying detection fallbacks when map APIs are unavailable
- Prevent ground-only mounts from being added to the flying rotation pool

## [1.0.0] - 2026-03-12

### Added
- Initial release
- One-button random mount summoning
- Separate ground and flying mount rotation pools
- Smart flying detection for Outland zones
- Configurable keybinding with modifier support
- Draggable minimap button with toggle
- GUI for managing mount pools (left-click = ground, right-click = flying)
- Slash commands: /onebuttonmount, /obm
