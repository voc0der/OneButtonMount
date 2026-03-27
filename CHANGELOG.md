## [Unreleased]

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
