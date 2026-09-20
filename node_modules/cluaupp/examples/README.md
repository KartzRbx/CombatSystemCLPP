# Sample game

Same Roblox service tree as `cluaupp init` (`templates/game`). Language samples: [CL++ examples](https://github.com/KartzRbx/CLPP/tree/main/examples).

| Folder | Rojo | Tag |
| --- | --- | --- |
| `src/ServerScriptService/*.server.clpp` | Script | server |
| `src/StarterPlayer/StarterPlayerScripts/*.client.clpp` | LocalScript | client |
| `src/StarterPlayer/StarterCharacterScripts/*.client.clpp` | LocalScript (character) | client |
| `src/ReplicatedStorage/Shared/*.clp` / `*.clh` | ModuleScript | none |

```bash
cd examples/game
npx cluaupp build .
```
