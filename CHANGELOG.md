## [Unreleased]

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
