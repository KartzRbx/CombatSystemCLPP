---
name: clpp-style
description: Write professional CL++ with small named functions, semantic identifiers, header/script split, and named callbacks. Always fix compiler diagnostics (unused parameters, types) instead of leaving them on screen. Use when refactoring .clpp/.clh, organizing combat or services, extracting lambdas, or when the user asks for código profissional, boa conduta, nomenclatura, or organização.
---

# CL++ professional style

Apply this whenever writing or refactoring CL++ in this repo.

## Conduct

1. Initialize everything. `int comboStage = 0;`, never an uninitialized local.
2. Small functions. One behavior, named after the behavior.
3. No magic numbers. `const float HITBOX_LIFE = 0.18;` on the struct.
4. Early return. `guard (cond) else { return; }` — no nested pyramids.
5. Headers declare, scripts define. Prototypes in `.clh`, bodies in `.clpp`.
6. Do not share mutable statics across server and client. Net or Keep, never a shared writeable singleton.
7. Procedures are `const bool`, never `const void` — void emits a broken Luau function type. Parameters always have a named type (`InputObject`, not `auto`).

## Callbacks

Never put combat/network logic inside `func () { }`.

The lambda only forwards to a named method. Call methods as `@this.Name(...)` (dot). `@Name(...)` emits a `pcall` and swallows errors.

```clpp
hitbox.Touched~>Connect(func (BasePart hitPart) {
	@this.OnHitboxTouched(hitPart, attacker, attackerCharacter, attackerEntity, struckPlayers);
});
```

Name event handlers `On` + event: `OnAttack`, `OnHitboxTouched`, `OnCharacterSpawned`, `OnReady`.
Name binders `Bind` + surface: `BindHitboxTouched`, `BindCombatRemotes`, `BindPlayerSessions`.
Name factories `Create` / `Spawn` / `Resolve` / `Try`.

## Naming

| Kind | Form | Example |
| --- | --- | --- |
| struct | PascalCase | `CombatServer` |
| method | PascalCase verb | `ResolveVictim`, `AdvanceCombo` |
| local / param | camelCase, role-first | `attackerEntity`, `hitPart`, `struckPlayers` |
| constant | SCREAMING_SNAKE | `ATTACK_INTERVAL`, `MAX_HEALTH` |
| player refs | role | `attacker`, `victim`, `player` — not `p`, `plr`, `currentPlayer` unless needed |
| Hive ids | `*Entity` | `fighterEntity`, `victimEntity` |

Do not abbreviate (`hp` → `currentHealth`, `box` → `hitbox`, `gp` → `gameProcessed`).

## Header layout

Group prototypes on the struct in this order:

1. Session bind / lifecycle
2. Queries (`IsFighterAlive`, `CanAcceptAttack`)
3. World writes (`SeedFighter`, `AdvanceCombo`)
4. Hitbox
5. Damage / replication

Keep constants next to the fields they configure.

## Script layout

Define methods in the same order as the header. `void init()` only calls two binders:

```clpp
void init() {
	CombatServer::BindPlayerSessions();
	CombatServer::BindCombatRemotes();
}
```

## Includes in a compiling script

```clpp
#pragma strict
#include <clpp/roblox.clh>
#include <clpp/libs/ward.clh>
#include "CombatServer.clh"
```

Angled library includes that must emit a `require` belong in the `.clpp`, not only the `.clh`.

## Comments

No narration. A name should replace a comment. If a workaround exists, one line pointing at the compiler limitation is enough.

## Never leave errors

Diagnostics are work, not a report. Do not stop, explain, or ask while the file still shows errors. Fix, rebuild, fix again until `cluaupp build` exits 0 and the compiling `.clpp` has no unused-parameter / type diagnostics.

CL++ does **not** count uses inside a nested `func () { }` as uses of the outer parameters. `BindHitboxTouched(hitbox, attacker, attackerCharacter, attackerEntity, struckPlayers)` will error `unused attackerEntity` if those names only appear in the `Touched` lambda. Mention every parameter in the method body (`guard`) before the lambda:

```clpp
const void CombatServer::BindHitboxTouched(Part hitbox, Player attacker, Model attackerCharacter, int attackerEntity, Roster struckPlayers) {
	guard (@this && hitbox && attacker && attackerCharacter && struckPlayers && attackerEntity) else {
		return;
	}
	hitbox.Touched~>Connect(func (BasePart hitPart) {
		@this.OnHitboxTouched(hitPart, attacker, attackerCharacter, attackerEntity, struckPlayers);
	});
}
```

Flare handlers must match the packet arity. If `attacker` / `comboStage` are unused, put them in the `guard` — do not drop them from the signature and do not leave the unused error on screen.

Truth is `cluaupp build`, not clangd / C++ IntelliSense on `.clpp`. If the editor squiggles but the compiler is clean, ignore the squiggle. If the compiler errors, change the code.
