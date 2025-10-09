# BCC CoreHUD — Full Modern HUD & Metabolism for RedM

An opinionated RedM HUD for player, mount, voice, temperature and cleanliness telemetry with a Vue 3/Tailwind SPA front end. The resource includes layout and palette editors, oxmysql persistence, additive core buffs, consumable helpers and optional auto-decay for hunger/thirst.

> **Quick start:** drop the resource in `resources/[BCC]/bcc-corehud`, ensure `oxmysql`, `vorp_core`, `vorp_inventory`, `bcc-utils`, and `feather-menu`, then `ensure bcc-corehud`.

## Highlights

- **Complete core suite** – Health, stamina, hunger, thirst, stress, temperature, money, gold, experience, tokens and horse telemetry, each with configurable warning thresholds.
- **Needs & buffs** – Built-in auto-decay or external data via exports. Consumables can push additive health/stamina boosts and golden core overpower using the RedM helpers.
- **Voice awareness** – Mumble proximity visualiser plus talking indicator, configurable labels and keybind cycling.
- **Cleanliness feedback** – Horse dirt badge and player cleanliness core with flies FX, cooldown-based warnings and starvation/penalty hooks.
- **Stress & temperature effects** – Optional stress penalties, temperature damage and starvation timers with fully tunable thresholds and intervals.
- **Mailbox & balances** – Built-in mailbox counter plus money, gold, experience, token and player-id cores that sync from VORP state bags/RPC.
- **Medical integration** – Optional bleed core slot with damage polling, notifications, and seamless bcc-medical support when present.
- **Palette & layout editor** – Drag, drop and recolour every widget in-game; snapshots persist per character through oxmysql.
- **Modular consumable config** – Need item definitions live in `shared/config/needitems/*.lua`; add or remove packs without touching core config.
- **Consumable QoL** – Need items can refund containers (e.g. empty bottles) or award bonuses after use through the `give` field.
- **Robust persistence** – Character layouts, palettes, needs and balances survive restarts. Automatic DB bootstrap via `server/dbUpdater.lua`.
- **Vue 3 SPA** – Vite-powered UI with hot reload for rapid iteration.

<img width="1913" height="1072" alt="image" src="https://github.com/user-attachments/assets/74dba634-08a8-4cfc-a9b6-0c1bd5a0c540" />

## Requirements

| Dependency | Purpose |
|------------|---------|
| [RedM (cerulean FXServer)](https://redm.net/) | Runtime |
| [oxmysql](https://github.com/overextended/oxmysql) | Layout/palette/needs persistence |
| [VORP Core](https://github.com/VORPCORE/vorp-core) *(recommended)* | Character resolution & balance sync |
| [bcc-utils](https://github.com/BryceCanyonCounty/bcc-utils) *(recommended)* | Shared helpers (consumables, horses, RPC) |
| [vorp_inventory](https://github.com/VORPCORE/vorp_inventory) | Automatic consumable registration |
| [feather-menu](https://github.com/feather-framework/feather-menu) | Palette editor UI |
| Node.js 18+ & Yarn 1.22+ *(optional)* | Building the NUI bundle when customising |

### Disabling the stock VORP HUD

When running `vorp_core`, disable its default gold/money/token/id displays so bcc-corehud can render those cores instead. In `resources/[VORP]/[vorp_essentials]/vorp_core/config/config.lua` ensure the UI flags are set to `true`:

```
    HideUi     = true
    HideGold   = true
    HideMoney  = true
    HideLevel  = true
    HideID     = true
    HideTokens = true
```

With VORP’s HUD hidden, keep the corresponding cores enabled in `bcc-corehud` (money, gold, experience, tokens, player ID) so they remain visible to players.

> **Heads-up:** You don’t need `vorp_metabolism` or `fred-metabolism`. bcc-corehud already handles needs persistence, optional auto-decay, consumable helpers, temperature/stress effects, and UI layout/palette tools—everything you need for a richer metabolism experience.

## Installation

1. Copy the repository into your server resources (keep the `[BCC]` folder if you like).
2. (Optional) Build the UI when making changes (skip this if you deploy a pre-built release):
   ```bash
   cd resources/[BCC]/bcc-corehud/ui
   yarn install
   yarn build
   ```
3. Ensure dependencies before the HUD in `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure feather-menu
   ensure bcc-utils
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
  - `give` – optional reward item granted after consumption, e.g. `{ item = 'empty_bottle', count = 1 }`.
- Bleed behaviour is controlled by `Config.EnableBleedCore` and the `Config.BleedCore` table (polling cadence, UI visibility). The HUD auto-notifies players when bleeding and exposes the `SetBleedStage` event/export for external resources.
- Stress and temperature systems sit under `Config.StressSettings`, `Config.MinTemp`, `Config.MaxTemp`, starvation settings, and related damage knobs—set values to `false` or `0` to disable individual effects.
- Mailbox and economy cores are toggled via `Config.EnableMailboxCore`, `Config.EnableMoneyCore`, `Config.EnableGoldCore`, `Config.EnableExpCore`, `Config.EnableTokensCore`, and `Config.EnableLogoCore`. Balances sync automatically through VORP state bags or the bundled RPCs.
- The shared `Notify` helper formats alerts (cleanliness, bleed, temperature, etc.) and falls back to console logging if an unknown notification backend is configured.
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

| Export | Purpose |
|--------|---------|
| `SetNeeds(payload)` | Overwrite hunger/thirst/stress with a table of values. |
| `SetNeed(stat, value)` | Set a single need (`hunger`, `thirst`, `stress`, `clean_stats`). |
| `AddNeed(stat, delta)` | Increment a need, including `clean_stats`. |
| `SetMailboxCount(count)` | Update the mailbox core. |
| `SetCleanStats(percent)` | Override cleanliness without touching auto-decay. |
| `SetMoney / SetGold / SetExp / SetTokens` | Update economy cores (also driven automatically by VORP state bags). |
| `SetLogo(path)` | Change the logo slot image. |
| `SetBleedStage(stage)` | Push bleed core state when integrating with other medical scripts. |
| `PlayConsumeAnimation(spec)` | Trigger the built-in consume animation helper. |

Example:

```lua
exports['bcc-corehud']:SetNeeds({ hunger = 75, thirst = 60, stress = 20 })
exports['bcc-corehud']:SetBleedStage(1) -- mark player as bleeding
```

### Server exports

| Export | Purpose |
|--------|---------|
| `GetPlayerNeeds(target)` | Fetch current hunger/thirst/stress for a player/character. |
| `GetPlayerNeed(target, stat)` | Read a single stat (`hunger`, `thirst`, `stress`). |
| `SetPlayerNeed(target, stat, value)` | Set a stat for the current character or a character id. |
| `AddPlayerNeed(target, stat, delta)` | Increment/decrement a stat (supports `clean_stats`). |

Need items registered via `Config.NeedItems` automatically call these helpers to persist changes.

### RPC & events

- `bcc-corehud:saveCores`, `bcc-corehud:layout:save`, `bcc-corehud:layout:request`, `bcc-corehud:palette:*` – server RPCs used by the UI.
- `bcc-corehud:setNeeds`, `bcc-corehud:setNeed`, `bcc-corehud:setBleedStage` – client events you can trigger from other resources.
- Bleed status fetcher: `BccUtils.RPC:CallAsync('bcc-corehud:bleed:request')` (automatically used when `bcc-medical` is running).

## Development workflow

1. `ensure bcc-corehud` on your dev server.
2. Run `yarn dev` inside `ui/` for hot reload during UI changes.
3. `yarn build` to produce production assets, then restart the resource.

## Notable Implementation Details

- Cleanliness warnings initialise lazily and only fire once you actually dip below `Config.MinCleanliness`, preventing notification spam on resource restarts.
- Bleed detection throttles damage polling when `bcc-medical` is present and falls back to client-side updates if not; the HUD still exposes manual setters for custom medical systems.
- The shared `Notify` helper automatically adapts to `feather-menu` or VORP notifications and falls back to console output if misconfigured.
- Particle FX attach using `StartNetworkedParticleFxLoopedOnEntityBone` with named asset helpers and `IsPedMale` for bone selection.
- Consumable buffs treat `health`/`stamina` as additive deltas; zero values leave cores untouched while positive values clamp to `[0, 100]`.
- Palette persistence accepts any key the UI sends, so custom themes survive reloads.
- Need item files use `AddNeedItems` to register themselves; you can register additional bundles from other resources before or after loading `bcc-corehud`.

## Credits & License

- Crafted by **BCC Scripts** (https://bcc-scripts.com).
- Vue 3, Pinia, Tailwind CSS, Vite power the web UI.
- Licensed under the terms in `LICENSE.md`.

Pull requests and issue reports are welcome. Enjoy the HUD!

- Need more help? Join the bcc discord here: https://discord.gg/VrZEEpBgZJ
