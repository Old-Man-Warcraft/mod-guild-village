# mod-guild-village

## Description

This module provides:

- Purchasable guild villages.
- Custom creatures and gameobjects.
- Custom village currency and expansion systems.
- Daily and weekly guild quests.
- Expedition, production, PvP reward, and teleporter systems.
- Configurable village limits and optional cleanup for inactive guild masters.

## Installation requirements

Guild Village reads its customs schema name from `GuildVillage.Database.Name`.
By default the module expects an existing `customs` schema and does not create it unless `GuildVillage.Database.AutoCreate = 1`.

For the customs autoupdater to work, the database user from `WorldDatabaseInfo` must also have access to the configured Guild Village schema:

```
GRANT CREATE ON *.* TO 'acore'@'127.0.0.1';
CREATE DATABASE customs CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON customs.* TO 'acore'@'127.0.0.1';
FLUSH PRIVILEGES;
```

If you want to use a different schema name, change `GuildVillage.Database.Name` and apply the grants to that schema instead.

If you installed the module before November 27, 2025, apply the legacy migration in `customs/archive/updates/014_important_update.sql` first. After that, the module updates itself automatically during server startup.

Optional logging:

```
Logger.gv.customs=3,Console Server
```

## Reserved IDs

The module uses fixed entries in these tables:

- `gameobject_template`
- `creature_template`
- `creature_template_model`
- `game_graveyard`
- `graveyard_zone`
- `fishing_loot_template`
- `points_of_interest`

Make sure these ranges are free in your `acore_world` database:

- Gameobjects: `990203`, `990204`
- Creatures: `987400`–`987430`, `987440`–`987454`
- Points of interest: `1200`–`1250`
- Graveyard entry: `2000`

If any of these IDs are already occupied, move the module to another free range in both code and SQL.

## Notes

- SmartAI was removed from the cooking and riding trainers. Only movement remains.
- The module uses a dedicated configurable customs schema for village-specific tables.
- `gv_gameobject_template` can pre-spawn objects before village creation. It is applied once during purchase.
- `gv_creature_template` can pre-spawn creatures before village creation. It is applied once during purchase.

## Documentation

- Wiki: [Documentation](https://github.com/BeardBear33/mod-guild-village/wiki/%5BEN%5D-Documentation)
- Root overview: [README.md](https://github.com/BeardBear33/mod-guild-village/blob/main/README.md)
