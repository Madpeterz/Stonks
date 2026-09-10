# Stonks

ArcheAge Classic addon that scans your inventory for tradable ship **Design**
items, totals their market value from a local price dataset, and paints a coloured
value band on each matching bag slot.

> "Its worth 1000g im sure" — Madpeter

## What it does

- **Bag value scan** — walks the Inventory bag, matches each item's `itemid`
  against `stonks.dat`, and logs the total value plus the top 3 items by unit price.
- **Bag slot overlay** — draws a thin coloured strip at the bottom of every bag
  slot holding a dataset item. Colour = value band (see below).
- **Design discovery** — rescans the bag for items whose name contains `design`
  (case-insensitive), skips housing/farm building designs, and appends any new
  ones to `stonks.dat` with `valueper = 0` for you to price later.
  spam the button to update!
- **Live refresh** — overlay redraws on `BAG_UPDATE` and `REMOVED_ITEM` while enabled.

## Usage

1. Install into your addon folder as `Stonks/` (see Install).
2. In game a 50x50 toggle button appears near the top-right of the screen.
   - **Click** — toggle the bag overlay on/off. On enable, a scan runs after ~4s.
   - **Shift + drag** — reposition the button. Position is saved.
   - **Click 5 times fast** (each within 600ms) — run design discovery and append
     new designs to `stonks.dat`.
3. Output goes to the addon log (`api.Log:Info`, prefixed `[Stonks]`).

## Price data — `stonks.dat`

Lua table serialised to disk, one row per item:

```lua
{
    itemname = "Seabreeze Shroudlight Design",
    itemid = 35999,
    valueper = 0,      -- unit value; edit this to price the item
}
```

- `itemid` is the lookup key. `itemname` is for reference only.
- `valueper` drives both the total-value math (`count * valueper`) and the
  overlay colour band. Ships with a seed list of ship Design items at `valueper = 0`.
- Edit `valueper` by hand, or let fast-click discovery add rows, then price them.

### Value bands / colours

| valueper `>=` | band | colour |
|--------------:|:----:|--------|
| 900.01 | 10 | purple-blue |
| 800.01 | 9  | dark red |
| 500.01 | 8  | gold |
| 300.01 | 7  | sky blue |
| 100.01 | 6  | yellowy red |
| 50.01  | 5  | red |
| 40.01  | 4  | orangy red |
| 10.01  | 3  | orange |
| 9.01   | 2  | pink |
| 7.01   | 1  | blue |
| else   | 0  | green |

## Install

Copy the repo contents into your ArcheAge addon directory so the path is:

```
<AAClassic>/Addon/Stonks/
    main.lua
    scanner.lua
    settings.lua
    constants.lua
    stonks.dat
    helpers/
    images/
```

## Layout

| File | Role |
|------|------|
| `main.lua` | Addon entry: UI button, click handling, event wiring, scan orchestration. |
| `scanner.lua` | Loads/saves `stonks.dat`; bag matching, value summary, design discovery. |
| `helpers/bagoverlay.lua` | Coloured value-band strips on bag slots. |
| `helpers/widgets.lua` | `CreateImageButton`, `makeWindowDraggable`. |
| `helpers/log.lua` | Dev logging helper. |
| `settings.lua` | Persisted settings: button X/Y, `uiDrawScale`. |
| `constants.lua` | Paths, overlay font sizing, building-name filter list. |
| `stonks.dat` | Item price dataset. |

## Settings

Stored via `api.SaveSettings("Stonks", ...)`:

| Key | Default | Meaning |
|-----|--------:|---------|
| `OpenButtonX` | 1499 | Toggle button X offset. |
| `OpenButtonY` | 716  | Toggle button Y offset. |
| `uiDrawScale` | 1.25 | Scale factor for the button. |

## Notes

- `constants.DEV_MODE = true` enables dev logging.
- The building-name list in `constants.lua` keeps housing/farm designs out of
  discovery scans; extend it if unwanted designs slip through.

## Author

Madpeter
