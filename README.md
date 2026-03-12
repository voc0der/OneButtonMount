# OneButtonMount

OneButtonMount is a World of Warcraft addon for TBC Anniversary Classic that summons a random mount from your configured rotation with one click or keybind.

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20504`

## Features

- One-button random mount summon
- Separate ground and flying rotation pools
- Outland flying detection with map and zone fallbacks
- Saved pool sanitization for removed/invalid mounts
- Configurable keybind with modifier and mouse support
- Draggable minimap button with show/hide toggle
- In-game configuration UI for managing pools

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
  - Left-click: add mount to Ground pool
  - Right-click: add mount to Flying pool
- Ground/Flying rotation rows:
  - Click an icon to remove it from that pool
- Keybind section:
  - Click "Click to Bind", press a key/mouse button, or clear it

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
