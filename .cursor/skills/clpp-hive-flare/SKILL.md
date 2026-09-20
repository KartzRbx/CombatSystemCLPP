---
name: clpp-hive-flare
description: Design server-authoritative combat with Hive ECS and Flare packets. Use when editing PlayerECS.hive, main.flare, CombatServer, CombatClient, hitboxes, AttackIntent, or when the user mentions Hive, Flare, ECS, snapshot, or hitbox.
---

# Hive + Flare combat

Server writes Hive columns and spawns the real hitbox. Client sends intent and a visual-only hitbox.

## Schema

`src/ReplicatedStorage/Shared/Services/Combat/PlayerECS.hive`:

```
opt name = PlayerECS

component Fighter { i32 userId }
component Health { i32 current, i32 max }
component Cooldown { f64 lastHit }
component Combo { i32 stage }
component Alive { i32 flag }
```

`src/ReplicatedStorage/Shared/Net/main.flare`:

```
opt name = Net

packet AttackIntent() from Client
packet CombatReady() from Client
packet CombatHello(i32 entityId, i32 health) from Server
packet HitResult(Player attacker, Player victim, i32 damage, i32 combo) from Server
```

Do not edit generated `PlayerECS.clh` or `Net.clh`. Change the schema and rebuild.

## Authority

- One `PlayerECS.New()` on the server struct.
- Map `Player → entity` with `Roster` (`Roster.New()`). Do not write `new Roster()` — CL++ emits `Instance.new("Roster")` and Studio crashes.
- Allocate ids with `NextEntity` (see clpp-language compiler notes).
- Client never `Set`s Hive columns. Client stores `EntityId` / `Health` from `CombatHello` / `HitResult`.
- `Ward.Allow(player, channel, rate, burst)` on every attack remote.

## Hitbox

On each accepted click:

1. Client `AttackIntent.FireServer()` then spawn local Part with `CanTouch = false`.
2. Server validates alive + cooldown + Ward, advances combo, spawns Part with `CanTouch = true`.
3. `Touched` lambda only calls `@this.OnHitboxTouched(...)`.
4. `OnHitboxTouched` resolves a player victim, dedupes with `Roster`, then `ApplyHit`.
5. `ApplyHit` writes Hive Health, assigns `humanoid.Health`, `HitResult.FireAll`.

Destroy hitboxes with `spawn { task::wait(life); hitbox.Destroy(); }`.

## Handshake

Client `init`: construct the struct, init fields, `SetupPlayerCombat()`, `CombatReady.FireServer()`.
Server `OnReady`: ensure fighter row, `CombatHello.Fire(player, entity, health)`.

## Includes

Server header may include `"ReplicatedStorage/Shared/Net/Net.clh"` and `"ReplicatedStorage/Shared/Services/Combat/PlayerECS.clh"`.

Client compiling script includes Net itself:

```clpp
#include "ReplicatedStorage/Shared/Net/Net.clh"
#include "../../../ReplicatedStorage/Shared/Services/Combat/CombatClient.clh"
```

After `cluaupp build`, open `out/StarterPlayer/StarterPlayerScripts/Controllers/CombatClient.client.luau` and confirm:

```luau
const Net = require(ReplicatedStorage.Shared.Net.Net)
```

If it still says `script.Parent.Parent.Parent.Parent.ReplicatedStorage`, Play will error `ReplicatedStorage is not a valid member of Players`.
