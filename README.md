# BCC Core HUD

An opinionated RedM HUD for player, mount, voice, temperature and cleanliness telemetry with a Vue 3/Tailwind SPA front end. The resource includes layout and palette editors, oxmysql persistence, additive core buffs, consumable helpers and optional auto-decay for hunger/thirst.

> **Quick start:** drop the resource in `resources/[BCC]/bcc-corehud`, ensure `oxmysql` and (optionally) `vorp_core` + `vorp_inventory`, then `ensure bcc-corehud`.

## Highlights

- **Complete core suite** – Health, stamina, hunger, thirst, stress, temperature, money, gold, experience, tokens and horse telemetry, each with configurable warning thresholds.
- **Needs & buffs** – Built-in auto-decay or external data via exports. Consumables can push additive health/stamina boosts and golden core overpower using the RedM helpers.
- **Voice awareness** – Mumble proximity visualiser plus talking indicator, configurable labels and keybind cycling.
- **Cleanliness feedback** – Horse dirt badge and player cleanliness core with optional flies FX, cooldown-based warnings and starvation/penalty hooks.
- **Palette & layout editor** – Drag, drop and recolour every widget in-game; snapshots persist per character through oxmysql.
- **Modular consumable config** – Need item definitions live in `shared/config/needitems/*.lua`; add or remove packs without touching core config.
- **Robust persistence** – Character layouts, palettes, needs and balances survive restarts. Automatic DB bootstrap via `server/dbUpdater.lua`.
- **Vue 3 SPA** – Vite-powered UI with hot reload for rapid iteration.

## Requirements

| Dependency | Purpose |
|------------|---------|
| [RedM (cerulean FXServer)](https://redm.net/) | Runtime |
| [oxmysql](https://github.com/overextended/oxmysql) | Layout/palette/needs persistence |
| [VORP Core](https://github.com/VORPCORE/vorp-core) *(recommended)* | Character resolution & balance sync |
| [vorp_inventory](https://github.com/VORPCORE/vorp_inventory) *(optional)* | Automatic consumable registration |
| [feather-menu](https://github.com/feather-framework/feather-menu) *(optional)* | Palette editor UI |
| Node.js 18+ & Yarn 1.22+ *(optional)* | Building the NUI bundle when customising |

## Installation

1. Copy the repository into your server resources (keep the `[BCC]` folder if you like).
2. (Optional) Build the UI when making changes:
   ```bash
   cd resources/[BCC]/bcc-corehud/ui
   yarn install
   yarn build
   ```
3. Ensure dependencies before the HUD in `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure vorp_core      # optional but recommended
   ensure bcc-corehud
   ```
4. Restart the server (`refresh` + `ensure bcc-corehud` works too). The database table is created automatically on first run.

## Configuration Overview

- Global options live in `shared/config/config.lua`.
- Need item definitions are split into category files under `shared/config/needitems/` (`foods.lua`, `drinks.lua`, `medical.lua`, `smokes.lua`, `drugs.lua`). Each file calls `AddNeedItems(items)` so new packs can be dropped in without editing the main config.
- Per-item fields:
  - `thirst`, `hunger`, `stress` – percents added to the current core values.
  - `health`, `stamina` – additive core boosts (0 ignores, positive values clamp to 100).
  - `OuterCore*/InnerCore*Gold` – durations for `EnableAttributeOverpower` (0 to ignore).
  - `prop`, `animation`, `duration` – visuals for the consume animation helper.
- Cleanliness and temperature sections expose damage, FX and warning toggles. Setting `Config.MinCleanliness` or temperature thresholds to `false` disables those features.
- Commands (`Config.CommandToggleHud`, `Config.CommandLayout`, `Config.CommandPalette`, etc.) can be reassigned or disabled (`false`).

### Sample: Adding a new consumable pack

```lua
-- shared/config/needitems/coffee.lua
local items = {
    { item = 'flatwhite', thirst = 12, hunger = 0, stress = -5, health = 0, stamina = 5, OuterCoreHealthGold = 0, InnerCoreHealthGold = 0, OuterCoreStaminaGold = 0, InnerCoreStaminaGold = 0, remove = true, prop = 'P_MUGCOFFEE01X', animation = 'drink', duration = 3500 },
}

AddNeedItems(items)
```

Add the new file to `shared/config/needitems/`, and the manifest will load it automatically.

## In-Game Tools

| Command | Default | Description |
|---------|---------|-------------|
| `/togglehud` | `Config.CommandToggleHud` | Toggle HUD visibility. |
| `/hudlayout` | `Config.CommandLayout` | Enter/exit drag-and-drop layout mode (`Esc` cancels). |
| `/hudpalette` | `Config.CommandPalette` | Open the palette editor when feather-menu is present. |
| `/clearfx` | `Config.CommandClearFx` | Stop active post-processing effects. |
| `/hudheal` | `Config.CommandHeal` | Refill hunger/thirst/stress/cleanliness (dev tool).

### Palette editor

1. `/hudpalette` to open the menu.
2. Tweak sliders; changes preview instantly.
3. Hit save (or `Esc`) to persist per character. Server-side validation stores every colour key.

### Layout editor

1. `/hudlayout` enables grid + drag handles.
2. Move components and Save Layout near map.
3. `/hudlayout reset` clears saved positions for the current character.

## Integrations & Events

### Client exports

```lua
-- Apply multiple needs at once
exports['bcc-corehud']:SetNeeds({ hunger = 75, thirst = 60, stress = 20 })

-- Adjust a single stat (hunger / thirst / stress)
exports['bcc-corehud']:SetNeed('hunger', 42)

-- Increment a stat (hunger / thirst / stress / clean_stats)
exports['bcc-corehud']:AddNeed('clean_stats', 100)
```

## Development workflow

1. `ensure bcc-corehud` on your dev server.
2. Run `yarn dev` inside `ui/` for hot reload during UI changes.
3. `yarn build` to produce production assets, then restart the resource.

Lint the UI (optional):

```bash
yarn lint
```

## Notable Implementation Details

- Cleanliness warnings initialise lazily and only fire once you actually dip below `Config.MinCleanliness`, preventing notification spam on resource restarts.
- Particle FX attach using `StartNetworkedParticleFxLoopedOnEntityBone` with named asset helpers and `IsPedMale` for bone selection.
- Consumable buffs treat `health`/`stamina` as additive deltas; zero values leave cores untouched while positive values clamp to `[0, 100]`.
- Palette persistence accepts any key the UI sends, so custom themes survive reloads.
- Need item files use `AddNeedItems` to register themselves; you can register additional bundles from other resources before or after loading `bcc-corehud`.

## Credits & License

- Crafted by **BCC Scripts** (https://bcc-scripts.com).
- Vue 3, Pinia, Tailwind CSS, Vite power the web UI.
- Licensed under the terms in `LICENSE.md`.

Pull requests and issue reports are welcome. Enjoy the HUD!
