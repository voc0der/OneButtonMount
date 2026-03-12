## [Unreleased]

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
