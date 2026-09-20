Native PascalCase libraries live in `runtime/<Name>`.

| Native | Notes |
| --- | --- |
| Flare | `.flare` → `out/` `--!native` write/read |
| Sweep | zelador; `~>` auto-binds |
| Spark | O(1) Disconnect, reentrant Fire queue, ConnectParallel |
| Keep | ProfileStore-class session lock, tagged buffers, escrow trades |
| Mint | `.mint` formatters, no ICU dump |
| Axiom | `.axiom` tree-shakes groups |
| Roster | PascalCase + buffer pack |
| Gleam | `{ .Field = }`, Sweep events |
| Bloom | ColorSequence paths, one scheduler |
| Lens | `Window(title, fn)` — no `End()` |
| Crest | Gleam icons |
| Pin | distance / occlusion / scale |
| Stage | Viewport Attach |
| Coil | Gleam.Spring uses Coil |
| Helm | `.helm` + Gleam console, Flare buffers |
| Shift | `.shift` → u8 ids, HSM |
| Hive | component columns, snapshot buffers, server-only writes by default |
| Ward | remote rate-limit, packet cap, speed strikes |
| Ember | Emit / Play / Stop / Sweep |
| Echo | CFrame snapshots as buffers |
| Guide | Flare + Gleam + Sweep |
| Trace | pretty-print; Lens uses Trace |
| Promise | evaera/roblox-lua-promise (vendored) |

`#include <clpp/libs/sweep.clh>` (etc). See `docs/src/content/docs/libraries`.

Re-vendor Promise only: `node scripts/vendor-libs.js`.
