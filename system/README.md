- `hardware`: basic config for a device, specifies screen resolution,
  gpu, etc
- `hosts`: mostly hardware-agnostic, specifies config for device "roles"
- `devices`: per-device config, like partition tables. This is the entry
  points which import modules from `hardware` and `hosts`
