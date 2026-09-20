---
name: clpp-language
description: Write valid CL++ (Cluaupp) that compiles to Luau. Always rebuild and fix unused-parameter and compile errors until cluaupp build is clean. Use when editing .clpp, .clh, .clp, .hive, or .flare files, compiling with cluaupp/clpp, or when the user mentions CL++, Cluaupp, Hive, Flare, or Roblox combat in this repo.
---

# CL++ language

CL++ is C++-inspired source that `clpp` emits as Luau. Cluaupp orchestrates Rojo, includes, Hive, and Flare. There is no `int main()`. Scripts enter at `void init()`.

Read [compiler.md](compiler.md) before using Hive `Entity` / `Has` / `Despawn`, `Humanoid.TakeDamage`, `Vector3::new`, or `namespace`.

## Files

| Source | Runtime |
| --- | --- |
| `*.server.clpp` | Script |
| `*.client.clpp` | LocalScript |
| untagged `.clpp` / `.clp` | ModuleScript — do not put `init()` unless require should run it |
| `.clh` in `src/` | inlined on quoted include |
| `#include <clpp/...>` | IntelliSense only; emits `CluauppLibs` require |

Entry scripts: `#pragma strict` then includes then functions then `void init()`.
Headers: `#pragma once`, structs, field defaults, method prototypes. Bodies live in `.clpp`.

## Accessors (law)

CL++ has no `->`. Instances are `Player player`, never `Player*`.

| Write | Meaning |
| --- | --- |
| `player.Name` / `player.Kick()` | property / instance method (`.` still passes self) |
| `player:Kick()` | protected `pcall` form — do not use as normal method call |
| `task::wait` / `Class::Method` / `CombatServer::OnAttack` | static, method definition, call on the struct table |
| `signal~>Connect(fn)` | Sweep janitor Connect |
| `"hi " .: name` | concat |
| `Enum.UserInputType.MouseButton1` | enum |
| `@this` / `@World` / `@janitor` | receiver / field **inside** `Class::Method` only, never in `init()` |

Lambdas: `func (Player player) { }`. Not `[]() {}`.

## Constructs to use

```clpp
guard (player) else {
	return;
}

spawn {
	task::wait(0.18);
	hitbox.Destroy();
};

for (Player player in players.GetPlayers()) {
	@this.RegisterFighter(player);
}

Part hitbox = new Part(workspace);
Vector3 size = Vector3(5, 6, 4);
CFrame offset = CFrame(0, 0, -3.2);
Color3 color = Color3(1, 0.25, 0.2);
Players players = GetService<Players>();
```

## Constructs that do not exist

`namespace` (use `struct`), `->`, `continue`, ternary, `do/while`, `try/catch`, `goto`, `Player*`, ISO `std::`, C++ captures `[&]`.

`wait()` as a free function is unreliable — use `task::wait` inside `spawn { }`.
`delay(n, fn)` is unreliable — use `spawn { task::wait(n); ... }`.

## Types and init

Prefer `auto` only for `FindFirstChild` / `FindFirstChildWhichIsA` results, Hive worlds (`auto World = PlayerECS.New()`), and Keep sessions (`auto Session = null`). Method parameters and other struct fields always have a named type (`InputObject`, `Player`). Do not type fields as `HiveWorld` or `Data` — those names are IntelliSense stubs and are not imported into the generated module. Initialize every field: `int coins = 0;`, never `int coins;`.
`null` is Luau `nil`.
`post` / `warn` / `report` → print / warn / error.

## Includes

- Quoted path from **src root** for generated modules: `#include "ReplicatedStorage/Shared/Net/Net.clh"`
- Relative quoted `.clh` next to the script: `#include "CombatServer.clh"`
- Never quoted-include Net/Hive generated headers from a Shared `.clh` that a LocalScript also includes — the require path follows the compiling file
- Library: `#include <clpp/libs/ward.clh>` in the **compiling** `.clpp` if the runtime require must appear in that script

## Fix until clean

After writing CL++, run `cluaupp build`. Unused parameters, bad includes, and type errors are blockers — change the code until the compiler is silent. Nested `func` captures do not count as uses; see [compiler.md](compiler.md).

## Layout

- Server systems: `src/ServerScriptService/Services/`
- Client controllers: `src/StarterPlayer/StarterPlayerScripts/Controllers/`
- Shared types/schemas: `src/ReplicatedStorage/Shared/`
- If it needs `DataStoreService`, it is server. If it needs `UserInputService`, it is client.
