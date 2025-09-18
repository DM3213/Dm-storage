dm-storage

Simple world-placed storage using ox_inventory stashes

Setup

- Run SQL in `dm-storage/sql.sql`.
- Add items to `ox_inventory/data/items.lua` (examples):
  - storage_small, storage_medium, storage_large (see snippet below)
- Ensure dependencies started: `ox_lib`, `oxmysql`, `ox_inventory`.
- Start resource after dependencies.

Usage

- Use storage item to place a prop, confirm with gizmo (if installed) or auto-place.
- Target the prop to Open Storage / Manage Access / Move / Pack Up.

Config

- Edit `dm-storage/config/storages.lua`:
  - Three tiers with `slots` and `weight` (e.g. small: 50 slots, 1000 weight).
  - Change `model` or item names as needed.

Items (ox_inventory)

Paste this snippet into `[ox]/ox_inventory/data/items.lua` inside the items table.

```
    ['storage_small'] = {
        label = 'Small Storage',
        weight = 0,
        stack = false,
        close = true,
        consume = 1,
        description = 'Place a small storage (50 slots, 1000 weight stash).',
        server = { export = 'dm-storage.useStorageSmall' },
    },

    ['storage_medium'] = {
        label = 'Medium Storage',
        weight = 0,
        stack = false,
        close = true,
        consume = 1,
        description = 'Place a medium storage (100 slots, 2000 weight stash).',
        server = { export = 'dm-storage.useStorageMedium' },
    },

    ['storage_large'] = {
        label = 'Large Storage',
        weight = 0,
        stack = false,
        close = true,
        consume = 1,
        description = 'Place a large storage (150 slots, 4000 weight stash).',
        server = { export = 'dm-storage.useStorageLarge' },
    },
```

Notes

- The export names match the auto-generated exports in `server/main.lua` (`use` + PascalCase of the item name).
- To change capacities, edit `slots`/`weight` in `config/storages.lua` — no item changes needed.
- Access control: The stash is registered with the owner’s CID at the ox_inventory layer; only the owner can open by default. The “Manage Access” UI lets the owner whitelist friends (by Player ID or CID). Whitelisted users can open via the prop interaction.
