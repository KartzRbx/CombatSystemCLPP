# Changelog

## 1.4.1

- **`cluaupp init --help`** names the 1.4.0 service tree (`ReplicatedStorage`, `ServerScriptService`, `StarterPlayer`), not `src/server` / `src/client` / `src/shared`.
- Handbook: Flare **Ready / Welcome / Session** handshake, Connection example, and leftover CLI/path pages aligned with the service layout.

## 1.4.0

- **Init** writes a Roblox service tree (`ServerScriptService`, `ReplicatedStorage/Shared`, `StarterPlayer`, `ServerStorage`, `ReplicatedFirst`) with DataBoot + TemplateData. Breaking: no more `src/server` / `src/client` / `src/shared`.
- Native CluauppLibs only: **Flare, Sweep, Spark, Keep, Mint, Axiom, Roster, Gleam, Bloom, Lens, Crest, Pin, Stage, Coil, Helm, Shift, Hive, Ember, Echo, Guide, Trace, Ward**. No Wally alias folders, no `@cluaupp/janitor` workspaces. Promise stays evaera. Libs ship inside the `cluaupp` npm tarball (`runtime/`).
- Buffer law: `.flare` / `.mint` / `.bloom` / `.helm` / `.shift` / `.hive` / `.axiom` pack u8 ids, ColorSequence, or tables — no JSON on the hot path. Net codec tables use tagged buffers (no `JSONEncode`).
- **Keep** is ProfileStore-class session lock plus duplication-proof trade escrow: `Reserve` deducts into a vault, `Commit` credits with receipts and `SaveWait`s both profiles (in-place rollback if a save fails), `AbortIfActive` on leave.
- **Ward** is the server anti-cheat kernel (rate-limit remotes, packet cap, speed strikes). Flare, Net, Keep replication, and Helm call Ward on inbound client buffers. Hive worlds are authoritative (client writes no-op) by default.
- **Sweep** is the zelador (`~>` Connect). **Spark** is engine-grade GoodSignal (O(1) Disconnect, reentrant Fire queue, `ConnectParallel`). **Shift** compiles FSM/HSM to u8. **Hive** is jecs-style ECS.
- Starlight handbooks per native name. HUD: Gleam+Mint+Bloom. NPC: Shift+Hive.
- Instance headers flatten inherited members and creatable classes get `Class()` plus `Class(Instance parent)`.
- Accept CL++ **0.3.3** (same JSON contract as 0.3.2).
- `#include <clpp/libs/keep.clh>` (and the other native headers) now insert `require(ReplicatedStorage.CluauppLibs.*)` even when CL++ does not list the lib in `artifact.libraries`. Template `include/clpp/libs/` ships every native `.clh`.

## 1.3.0

Align with CL++ **0.3.2**.

- Require `clpp` 0.3.2 (`CLPP` / `CLPP_PATH`, then PATH, then `%LOCALAPPDATA%\Programs\CLPP`).
- Instances are class names: `Player player`, never `Player*`. Default listen is `~>Connect`; fire with `.Fire`.
- `@this` / `@field` only inside `Class::Method`. `void init()` holds a local Janitor.
- Compile failures surface `diagnostics[]` (1-based). `watch` compiles with async `spawn`.
- Templates, examples, headers, and handbook match the 0.3.2 operator table.
- Docs site is Starlight (Astro) in `docs/`, with the official CL++ TextMate grammar for `clpp` fences.

## 1.2.1

Align with CL++ **0.3.0** accessors.

- `.` is properties, table keys, **and** instance methods (`player.Name`, `DataService.Server`, `player.FindFirstChild("x")`).
- `:` is **not** a table/property accessor. It is types (`age: int`) and protected calls (`player:Kick()` → `pcall`).
- `::` stays for statics and manual Connect (`task::wait`, `Color3::fromRGB`, `players.PlayerAdded::Connect`).
- Pick the newest `clpp` on PATH. Refuse compilers older than **0.3.0**.
- Language diagnostics stay with `clpp install` (no keystroke recompile from Cluaupp).
- Range-for is `for (T x in list)`.

## 1.2.0

Properties use `.`. Manual Connect uses `::`: `players.PlayerAdded::Connect(fn)`. Instance methods also use `.` (`player.FindFirstChild`). Do not use `:` for tables.

## 1.1.0

CL++ 0.3.0: anonymous callbacks are `func (params) { }`. `func [](…)` and C++ capture lists are rejected by `clpp`.

- Examples, README, migration table, and docs use `func (…)` / `func ()`.
- Requires CL++ **0.3.0** on PATH (`clpp install` for the error lens).

## 1.0.0

Breaking: Cluaupp no longer transpiles a C++ subset. Games are **CL++** (`.clpp` / `.clp` / `.clh`). The CLI orchestrates the [`clpp`](https://github.com/KartzRbx/CLPP) binary (`clpp api compile`), post-processes Luau (`ClppLibs` → `ReplicatedStorage.CluauppLibs`), and writes `out/` for Rojo.

- Requires `clpp` on PATH (`CLPP_PATH` override). Language, IntelliSense, and codegen live in CL++ (`clpp install`).
- `cluaupp language` prints `clpp api manifest`.
- Templates and `examples/game` use CL++ syntax (`guard`, `match`, `signal`, `.:`, `::`, Fusion).
- Docs site and README are CL++ × Luau (no clangd / `.cpp` toolchain).
- Tree-sitter C++ frontend removed. ForeverHD `"architecture": true` folder split is not implemented on this path.
- See [migration](docs/migration.md) and [CL++ docs](https://kartzrbx.github.io/CLPP/).

## 0.2.3

- Parser accepts `(void)x`, `static_cast<T>(x)`, `static constexpr` fields, and lambdas (`[](Player* p) { ... }`, `[&]`, `[=]`) so `Connect` / `BindToClose` compile without named-function wrappers.
- Parser keeps `LuaArray<T>` / `vector<T>` field types on structs (`HotBar` / `Storage` on a Template).
- `string_concat(...)` joins to Luau `..` (alongside string `+`).
- Cursor is not a licensed host for Microsoft `ms-vscode.cpptools`. Cluaupp no longer writes `C_Cpp.*` settings or `c_cpp_properties.json`; `watch` strips leftover keys and marks cpptools as unwanted. C++ completion stays clangd.
- Docs site is a C++-class handbook (syntax through lambdas and Luau `--!strict`). Per-class and per-enum dump pages are gone; engine members stay on create.roblox.com.
