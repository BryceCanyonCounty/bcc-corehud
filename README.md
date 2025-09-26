# BCC Core HUD

An opinionated RedM HUD, mount and environment cores with a modern Vue 3 interface.

## Highlights

- Player cores: health and stamina inner/outer rings with low-core warnings.
- Mount telemetry: horse health, stamina and a dedicated cleanliness core that shows the `horse_dirty` badge when your mount needs grooming.
- Environment awareness: a temperature core that surfaces cold/hot effects without hijacking player icons.
- Automatic persistence (optional): stores the latest core snapshot per character using oxmysql.
- Vue 3 + Tailwind UI compiled with Vite; hot reload during development and lightweight production builds.

## Requirements

| Component | Purpose |
|-----------|---------|
| [VORP Core](https://github.com/VORPCORE/vorp-core) | Character data and game exports |
| [oxmysql](https://github.com/overextended/oxmysql) | Database persistence (optional but enabled by default) |
| Node.js 18+ & Yarn | Building the NUI bundle |

## Installation

1. Copy `bcc-corehud` into your server `resources` folder (keeping the `[BCC]` parent is recommended).
2. Install UI dependencies and build the production bundle:
   ```bash
   cd bcc-corehud/ui
   yarn install
   yarn build
   ```
3. Add to your `server.cfg` (after loading VORP core and oxmysql):
   ```cfg
   ensure oxmysql
   ensure vorp_core
   ensure bcc-corehud
   ```
4. Restart the server or run `refresh`/`ensure bcc-corehud` from the console.

## Configuration

Edit `config.lua` to tailor behaviour:

| Setting | Default | Description |
|---------|---------|-------------|
| `Config.AutoShowHud` | `true` | Auto-display HUD after spawn. Toggle with `/togglehud`. |
| `Config.UpdateInterval` | `1000` | Snapshot interval in ms. |
| `Config.LowCoreWarning` | `25.0` | Percent threshold for low-core effects. |
| `Config.Debug` | `true` | Verbose logging for troubleshooting. |
| `Config.HorseDirtyThreshold` | `4` | Dirtiness attribute rank that triggers the dirty core. Set to `false` to disable. |
| `Config.TemperatureColdThreshold` | `-3.0` | Celsius value that spawns the cold core. Use `false` to disable. |
| `Config.TemperatureHotThreshold` | `26.0` | Celsius value for the hot core. Use `false` to disable. |
| `Config.SaveToDatabase` | `true` | Enable oxmysql persistence. |
| `Config.SaveInterval` | `15000` | Minimum ms between stored snapshots per player. |
| `Config.DatabaseTable` | `'bcc_corehud'` | Table used for snapshots. |
| `Config.AutoCreateTable` | `true` | Auto-creates/patches the table on resource start. |

## Controls

- `/togglehud` – toggles the HUD visibility client-side.
- HUD core order (left to right): player health, player stamina, horse health, horse stamina, horse dirt (when applicable), temperature (when applicable).

## Development

- Run the UI in hot-reload mode while the resource is started:
  ```bash
  cd ui
  yarn dev
  ```
  The NUI will proxy requests to the development server; stop it before building for production.

- Lint and fix UI files:
  ```bash
  yarn lint
  ```

## Database Schema

If `Config.AutoCreateTable` is `true`, the resource ensures the following structure (varchar columns truncated for brevity):

```sql
CREATE TABLE IF NOT EXISTS `bcc_corehud` (
  `character_id` VARCHAR(64) PRIMARY KEY,
  `innerhealth` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `outerhealth` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `innerstamina` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `outerstamina` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `innerhorse_health` TINYINT UNSIGNED NULL,
  `outerhorse_health` TINYINT UNSIGNED NULL,
  `innerhorse_stamina` TINYINT UNSIGNED NULL,
  `outerhorse_stamina` TINYINT UNSIGNED NULL,
  `innerhorse_dirt` TINYINT UNSIGNED NULL,
  `outerhorse_dirt` TINYINT UNSIGNED NULL,
  `innertemperature` TINYINT UNSIGNED NULL,
  `outertemperature` TINYINT UNSIGNED NULL,
  `effect_health_inside` VARCHAR(32) NULL,
  `effect_stamina_inside` VARCHAR(32) NULL,
  `effect_horse_health_inside` VARCHAR(32) NULL,
  `effect_horse_stamina_inside` VARCHAR(32) NULL,
  `effect_horse_dirt_inside` VARCHAR(32) NULL,
  `effect_horse_dirt_next` VARCHAR(32) NULL,
  `effect_temperature_inside` VARCHAR(32) NULL,
  `effect_temperature_next` VARCHAR(32) NULL,
  `horse_active` TINYINT(1) NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Disable persistence if you prefer to keep the HUD entirely client-side.

## Credits

- Built by **BCC Scripts** on top of the VORP ecosystem.
- Vue 3 / Tailwind UI bootstrapped from the BCC boilerplate.
