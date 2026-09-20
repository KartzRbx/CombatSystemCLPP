# CL++ compiler workarounds (0.7.x)

These are emit bugs, not style. Prefer the workaround until `clpp` generates a colon call.

## Hive

`World.Entity()`, `World.Has(...)`, `World.Despawn(...)` often emit `.Entity()` / `.Has()` / `.Despawn()` (no self).

| Need | Write |
| --- | --- |
| new id | `int id = @NextEntity; @NextEntity += 1;` |
| membership | `auto value = @World.Get(entity, Comp); if (!value) return;` |
| despawn | `@World.Remove(entity, Comp);` per component |

`PlayerECS.New()` is authoritative. Only the server writes columns. Client worlds do not spawn rows.

Generated `PlayerECS.clh` may contain `namespace PlayerECS`. Do not copy that into hand-written `.clh`. Use the generated names as `PlayerECS.Health`.

## Roblox instances

`humanoid.TakeDamage(n)` may emit without colon. Write `humanoid.Health = currentHealth;`.

`Vector3::new(x, y, z)` fails semantic check. Write `Vector3(x, y, z)`. Same for `CFrame(...)` and `Color3(...)`.

Player-local hitbox offset is CFrame multiply, not LookVector math and not `ToWorldSpace` in source:

```clpp
return rootPart.CFrame * CFrame(0, 0, @HITBOX_FORWARD);
```

Native CL++ still emits `.ToWorldSpace(` without colon (`self` becomes the offset at world origin). Cluaupp postprocess rewrites that to `:ToWorldSpace(`. Prefer `*` in source.

Cluaupp reindents emitted Luau (tabs). Do not hand-fix `out/` indent.

`~>` Connect: Cluaupp hoists the method Sweep to `self.janitor` (one per controller). Hitbox/player binds `LinkToInstance` so they die with that instance. Do not add a second `new Sweep()` next to `~>`.

## Flare

`FireAll` on generated packets is a function on the packet table (`api.FireAll`), so `.FireAll(...)` is correct.

`Fire` / `FireServer` take self — `.Fire(player, ...)` is the CL++ instance-method form.

Connect packets with Sweep: `Net.AttackIntent~>Connect(func (Player player) { @this.OnAttack(player); });`

`clpp` emits `require(script.Parent.Parent...ReplicatedStorage.Shared.Net.Net)`. Under `PlayerScripts` that path is `Players.ReplicatedStorage` and crashes. Cluaupp postprocess rewrites those requires to `require(ReplicatedStorage.Shared...)`. After a build, client files must show `game:GetService("ReplicatedStorage")`, never a `script.Parent` chain into `ReplicatedStorage`.

Do not put `table.pack(...)` inside a nested `function()` in Flare — `...` is only valid in the vararg function. Pack first, then `pcall`.

## Callbacks

Keep `func (...) { }` as a one-line dispatch to a named `Class::Method`. Business logic belongs in the method so `@this` and fields work.

Call other methods with a dot on the receiver. `@Name(...)` emits `pcall` (`self:Name`) and hides errors.

```clpp
hitbox.Touched~>Connect(func (BasePart hitPart) {
	@this.OnHitboxTouched(hitPart, attacker, attackerCharacter, attackerEntity, struckPlayers);
});
```

## Struct export types

`auto` on a method parameter emits a nameless type (`input,` with no annotation). Use a real type: `InputObject input`, never `auto input`.

`const void Method();` emits `(self: T),` — invalid Luau, missing `-> ()`. Declare procedures as `const bool Method();`, `return false` on guard failure, `return true` at the end.

Uninitialized fields emit `nil` in the constructor. Write `int ComboStage = 0;`, never `int ComboStage;`.

`auto World` emits `World: any`. Do **not** type the field as `HiveWorld` — that name is only an IntelliSense stub in `hive.clh`. It is not imported into the generated module.

`Data Session` is the same trap. `struct Data` in `keep.clh` is IntelliSense; CL++ treats `Data` as library type `DataService` and fails `CLPP0605`. Write `auto Session = null;` then ` @Session = Keep.Client.Init();`.

Construct with `Roster.New()`. Do not write `new Roster()` — CL++ emits `Instance.new("Roster")`, which is not a Roblox class. Cluaupp also rewrites leftover `Instance.new("Roster")` to `Roster.new()`.

## Unused parameters

A name used only inside `func () { }` is unused. The compiler still flags it. Bind it in the outer `guard` (or assign it to a field) so the diagnostic disappears. Do not ignore unused errors.

## Multiline return

Do not write `return (` across lines. Split into locals:

```clpp
bool isMouse = input.UserInputType == Enum.UserInputType.MouseButton1;
bool isTouch = input.UserInputType == Enum.UserInputType.Touch;
return isMouse || isTouch;
```

## Verify

After every edit run `node ./node_modules/cluaupp/bin/cluaupp.js build`. If it fails, fix the source and build again. Do not leave unused-parameter, type, or include errors visible. Open the matching `out/**/*.luau` and confirm `require` paths and `:` method calls.
