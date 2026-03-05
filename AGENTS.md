# AGENTS.md

## Repository workflow notes
- Primary runtime file is `miner.ahk`; `script.ahk` only includes it.
- Prefer editing `config.ini.example` and docs together when config keys change.
- Keep backward compatibility in `LoadConfig()` whenever possible.

## Documentation expectations
When configuration structure changes, update all of:
- `README.md`
- `docs/CONFIG_REFERENCE.md`
- `docs/MODULES.md`
- `docs/QUICK_START.md`

## Config conventions
- Preferred categories: `[main]` + module-scoped sections (`[module_*]`).
- Put migration/legacy aliases into `[deprecated]` and mark clearly.
- Coordinate lists use `x,y|x,y` format.
