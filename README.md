# BCC Core HUD

An opinionated RedM HUD for player, mount, voice and environment telemetry with a Vue 3 / Tailwind front end. The resource ships with persistence, an in-game layout editor, optional auto-needs decay, and a minimal API for other scripts to feed hunger, thirst or stress data.

## Feature Overview

- **Player cores** – Health and stamina inner/outer rings with low-core warning badges and configurable damage when starving or dehydrated.
- **Needs tracking** – Hunger, thirst and stress rings that can be driven by another resource (via export) or by the built-in auto-decay logic.
- **Voice indicator** – Microphone core that shows when the player is talking and fades range intensity based on Mumble proximity.
- **Mount telemetry** – Horse health, stamina and a dedicated dirtiness badge that lights up when the configured attribute threshold is reached.
- **Environment awareness** – Hot and cold icons appear only while the player is overheating or freezing, with a separate degree core for quick reference.
- **Layout & palette editor** – Drag-and-drop every core, align with the overlay grid, escape with `Esc`, and optionally tweak colours through the palette menu. Positions and palettes are stored per character.
- **Persistence with migration support** – Uses oxmysql to snapshot cores, palettes and layouts. The bundled migration script keeps the table up to date.
- **Vue 3 single page UI** – Built with Vite for fast local development and tiny production bundles.
- **Consumable registration helper** – Optionally auto-register food/drink items with `vorp_inventory`, making it easy to connect your item shop to the needs system.

## Requirements

| Dependency | Purpose |
|------------|---------|
| [RedM](https://redm.net/) (cerulean FXServer) | Target runtime |
| [oxmysql](https://github.com/overextended/oxmysql) | Database persistence (enabled by default) |
| [VORP Core](https://github.com/VORPCORE/vorp-core) | Character resolution & optional needs data (recommended) |
| [feather-menu](https://github.com/feather-framework/feather-menu) | Provides the in-game palette menu (optional but supported) |
| [vorp_inventory](https://github.com/VORPCORE/vorp_inventory) | Needed when using the consumable auto-registration helper |
| Node.js 18+ & Yarn 1.22+ | Building the NUI bundle (already compiled in releases, required for local changes) |

> The HUD can run without an external needs resource. When `Config.NeedsResourceName` is `false`, the client applies local hunger/thirst decay using the timings in `config.lua`.

## Installation

1. Place the `bcc-corehud` folder inside your server `resources` directory (keeping the `[BCC]` wrapper is fine).
2. If you plan to customise the UI, install dependencies and build the bundle:
   ```bash
   cd resources/[BCC]/bcc-corehud/ui
   yarn install
   yarn build
   ```
   (The repository ships with a compiled `ui/dist`, so this step is optional for plug-and-play installs.)
3. Ensure the resource after your database and core dependencies in `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure vorp_core
   ensure bcc-corehud
   ```
4. Restart the server or run `refresh` followed by `ensure bcc-corehud` from the console.

On first start the `server/dbUpdater.lua` script creates (or upgrades) the `bcc_corehud` table using the name defined in `Config.DatabaseTable`.

## Commands & Shortcuts

| Command / key | Description |
|---------------|-------------|
| `/togglehud` | Toggle the HUD visibility for the current client. |
| `/hudlayout` | Enter/exit layout edit mode. Use `/hudlayout reset` to clear saved positions. |
| `/hudpalette` | Open the palette editor when `PaletteMenu` is available. |
| `Esc` (while editing) | Exit layout mode instantly without saving. |

### Layout Editor Basics

1. Run `/hudlayout` – a grid overlay will appear and the cores become draggable.
2. Drag each core into position (default placement is a vertical stack bottom-left).
3. Press `Esc` or rerun `/hudlayout` to exit. Positions persist per character; you can reset from the same command.
4. When editing, stub icons appear for cores you do not currently have data for (temperature, horse stats, etc.).

## Configuration

All options live in `config.lua`. The table below highlights the most relevant groups—see the file for inline comments and defaults.

### HUD Behaviour

| Option | Default | Notes |
|--------|---------|-------|
| `Config.AutoShowHud` | `false` | Auto-toggle HUD on spawn. If `false`, players must run `/togglehud`. |
| `Config.UpdateInterval` | `1000` ms | Frequency of HUD snapshots sent to the UI. |
| `Config.LowCoreWarning` | `25.0` | Percent threshold that triggers the “wounded/drained/starving/parched/stressed” labels. |
| `Config.Debug` | `true` | Enables verbose client logging. |
| `Config.HorseDirtyThreshold` | `4` | Attribute rank (0–10) that enables the dirty horse badge. Set to `false` to disable the core. |
| `Config.EnableVoiceCore` | `true` | Toggle the voice proximity core entirely. |
| `Config.VoiceMaxRange` | `12.0` m | Max Mumble range used to normalise the voice ring fill. |

### Needs & Decay

| Option | Default | Notes |
|--------|---------|-------|
| `Config.NeedsResourceName` | `false` | Name of a resource exposing `GetNeedsData()`. When provided, the HUD polls it instead of using local decay. |
| `Config.NeedsAutoDecay` | `true` | Master toggle for built-in hunger/thirst decay when no external resource is configured. |
| `Config.NeedsDecayStartDelay` | `300.0` sec | Grace period after eating/drinking before decay resumes. |
| `Config.HungerDecayDuration` | `1800.0` sec | Time for hunger to drain from full to empty once decay begins. |
| `Config.ThirstDecayDuration` | `1200.0` sec | Same for thirst. |
| `Config.HotThirstMultiplier` | `2.0` | Extra thirst decay when overheating. |
| `Config.CrossNeedDecayMultiplier` | `1.5` | Multiplier applied to the remaining need when the other is empty. |
| `Config.StarvationDamageDelay` | `120.0` sec | Delay after both hunger and thirst hit zero before health damage starts. |
| `Config.StarvationDamageInterval` | `10.0` sec | Interval between starvation ticks. |
| `Config.StarvationDamageAmount` | `4.0` HP | Damage applied each tick once starving begins. |

### Temperature & Damage

| Option | Default | Notes |
|--------|---------|-------|
| `Config.TemperatureColdThreshold` | `-3.0` °C | World temperature that triggers the cold icon. Set to `false` to disable. |
| `Config.TemperatureHotThreshold` | `26.0` °C | Threshold for the hot icon. |
| `Config.AlwaysShowTemperature` | `true` | Keeps the degree core active even without a temperature effect; the hot/cold icon still appears only during extremes. |
| `Config.TemperatureMin` / `Max` | `-15.0` / `40.0` | Range mapped to the temperature meter used for the degree core. |
| `Config.TemperatureDamageDelay` | `5.0` sec | Delay before hot/cold damage is applied. |
| `Config.HotTemperatureDamagePerSecond` | `0.5` | Health damage per second when overheating. |
| `Config.ColdTemperatureDamagePerSecond` | `0.5` | Health damage per second when freezing. |

### Persistence & Database

| Option | Default | Notes |
|--------|---------|-------|
| `Config.SaveToDatabase` | `true` | Disable to keep layouts/palettes client-side only. |
| `Config.SaveInterval` | `15000` ms | Minimum delay between stored snapshots per character. |
| `Config.DatabaseTable` | `'bcc_corehud'` | Override the table name if required. |

### Consumable Registration

Setting `Config.RegisterNeedItems = true` will register each entry in `Config.NeedItems` with `vorp_inventory`, automatically applying hunger/thirst/stress adjustments when those items are used. This is optional but helps tie the HUD into your broader economy.

## Integration API

### Client Exports

```lua
-- Apply multiple needs at once
exports['bcc-corehud']:SetNeeds({ hunger = 80, thirst = 55, stress = 10 })

-- Update a single stat (hunger / thirst / stress)
exports['bcc-corehud']:SetNeed('hunger', 45)
```

### Client Events

| Event | Parameters | Purpose |
|-------|------------|---------|
| `bcc-corehud:setNeeds` | `(table payload)` | Apply hunger/thirst/stress percentages remotely. |
| `bcc-corehud:setNeed` | `(string stat, number value)` | Adjust a single need. |
| `hud:client:changeValue` | `(string stat, number value)` | Legacy alias used by several frameworks. |

### Server Utilities

| Event | Purpose |
|-------|---------|
| `bcc-corehud:layout:request / save / reset` | Sync layout positions per character. |
| `bcc-corehud:palette:request / save` | Sync palette data. |
| `bcc-corehud:saveCores` | Internal event used for persistence.

You can also push layouts or needs from the server with `TriggerClientEvent('bcc-corehud:layout:apply', src, positions)` or `TriggerClientEvent('bcc-corehud:setNeeds', src, payload)`.

## Development Workflow

1. Start the resource in RedM.
2. From `ui/`, run `yarn dev` – Vite will serve the SPA with hot module reload.
3. Once satisfied, build production assets using `yarn build` and restart the resource.

Linting (optional):

```bash
yarn lint
```


## Credits & License

- Built by **BCC Scripts** for the RedM servers.
- HUD UI authored with Vue 3, Pinia and Tailwind CSS.
- See `LICENSE.md` for usage terms.

Enjoy the HUD! Contributions and pull requests are welcome.
