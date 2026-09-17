#pragma once

// Parihsz/Chrono — custom character replication, vendored into CluauppLibs.Chrono
class ChronoHolder {};
class ChronoEntity {};
class ChronoStats {};
class ChronoConfig {};
class ChronoReplicationRules {};
class ChronoEvents {};
class ChronoSnapshots {};
class ChronoServerClock {};
class ChronoPlayer {};

namespace Chrono {
	void Start();
	void Start(ModuleScript* config);
	ChronoHolder* Holder();
	ChronoEntity* Entity();
	ChronoStats* Stats();
	ChronoConfig* Config();
	ChronoReplicationRules* ReplicationRules();
	ChronoEvents* Events();
	ChronoSnapshots* Snapshots();
	ChronoServerClock* ServerClock();
	ChronoPlayer* Player();
}
