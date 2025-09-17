-- Storage definitions (models can be changed to your liking)
Config.Storage = Config.Storage or {
  StashPrefix = 'storage_',
}

-- Three storage tiers. Keys are used as object types and item export names.
-- Ensure matching items exist in ox_inventory (e.g., 'storage_small').
Config.Objects = Config.Objects or {
  small = {
    item       = 'storage_small',
    label      = 'Small Storage',
    model      = 'prop_ld_int_safe_01',
    spawnRange = 50,
    slots      = 50,
    weight     = 100000, 
  },
  medium = {
    item       = 'storage_medium',
    label      = 'Medium Storage',
    model      = 'sf_prop_v_43_safe_s_bk_01a',
    spawnRange = 50,
    slots      = 100,
    weight     = 200000,
  },
  large = {
    item       = 'storage_large',
    label      = 'Large Storage',
    model      = 'm23_2_prop_m32_safe_01a',
    spawnRange = 50,
    slots      = 150,
    weight     = 400000,
  },
}

