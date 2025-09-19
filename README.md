

# dm-storage

dm-storage is a simple yet advanced world-placed storage system for FiveM, powered by ox_inventory stashes.
It supports both player-placed props (using items) and admin-created storages with full management.

# Features

Player storage props:

Use items (storage_small, storage_medium, storage_large) to spawn storage props.

Placement preview with object_gizmo (if installed) or auto-place fallback.

Interact with props via ox_target or qb-target:

Open Storage

Manage Access (whitelist friends by CID/ID)

Move

Pack Up (return as item)

Virtual storage (no world prop).

Admin Panel:

Search/filter storages by ID, name, owner, type, or mode.

Change access mode (public, job, private).

Assign job restrictions (when in job mode).

Transfer ownership to another CID.

Open stash directly.

Teleport to stash location.

Delete storages.

Create new storages:

Choose type (small/medium/large/virtual).

Name it (optional).

Assign an owner (optional, default = creator).

For prop storages: preview with gizmo to move/rotate before confirming.

# Setup

Run the SQL in dm-storage/sql.sql.

Add storage items to ox_inventory/data/items.lua:

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



Dependencies required:

ox_lib

oxmysql

ox_inventory

object_gizmo (optional but recommended)

Start dm-storage after dependencies.

# Admin Access

Admins are not group-based. Instead, you explicitly whitelist identifiers in config.lua:

Config.Admin = {
    licenses = {
        "license:27d8fbc6370ed3182f15ca587e74f55e8ef64d231"
    },
    steam    = {
        "steam:110000112345678"
    },
    discord  = {
        "discord:123456789012345678"
    },
}


Any player with one of these identifiers can open the Admin Panel and manage storages.

# Access Control

Owner → always has access.

Public → anyone can open.

Job → restricted to players with matching job name.

Private → only whitelisted CIDs.

Admins can override via the panel.

# Notes

Stashes are dynamically registered in ox_inventory.

Props auto-clean up when deleted or packed.

Virtual storages behave the same as props but don’t spawn objects.

Admin-created props include preview & gizmo placement.
