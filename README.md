<p align="center">
  <img src="assets/onebuttonmount-icon.png" alt="OneButtonMount icon" width="180" />
</p>

<h1 align="center">OneButtonMount</h1>

<p align="center">
  TBC Anniversary Classic random-mount addon with smart pool rules and reliable keybind chords.
</p>

<p align="center"><strong>Current version:</strong> <code>1.0.8</code></p>

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20504`

## Features

- One-button random mount summon
- Separate ground and flying rotation pools
- Flyable-area detection with API, map, and zone fallbacks
- Saved pool sanitization for removed/invalid mounts
- Configurable keybind with modifier and mouse chord support (including side buttons)
- Draggable minimap button with show/hide toggle
- In-game configuration UI for managing pools
- Mount source compatibility across companion, mount journal, and bag-mount item APIs

## AQ40 Rules

- Inside AQ40 (`Temple of Ahn'Qiraj`): only configured Qiraji Resonating Crystals are eligible
- Outside AQ40: Qiraji crystal mounts are excluded from random selection even if configured
- These rules apply to both manual summon (`/obm mount`) and keybind summon

## Installation

1. Download or clone this repository.
2. Place the `OneButtonMount` folder in:
   - `World of Warcraft/_classic_/Interface/AddOns/`
3. Launch the game and enable `OneButtonMount` in the AddOns list.

## Usage

- `/onebuttonmount` or `/obm`: Open/close config UI
- `/obm mount`: Summon random mount immediately
- `/obm minimap`: Toggle minimap button
- `/obm help`: Show command help

## Config UI

- Available mounts list:
  - Left-click adds a mount to Ground pool
  - Right-click adds a mount to Flying pool
- Ground/Flying rotation rows:
  - Click an icon to remove it from that pool
- Keybind section:
  - Click "Click to Bind", press a key/mouse button, or clear it
  - Example chord: `SHIFT-BUTTON5`

## Development

Run local tests:

```bash
lua tests/run.lua
```

Syntax check:

```bash
luac -p OneButtonMount.lua
```

## Releasing

Release workflow details are in [`RELEASING.md`](RELEASING.md).

## License

MIT. See [LICENSE](LICENSE).

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=voc0der/OneButtonMount&type=Date)](https://star-history.com/#voc0der/OneButtonMount&Date)
