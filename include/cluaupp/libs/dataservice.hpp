#pragma once

// KartzRbx/DataServiceV2 — https://github.com/KartzRbx/DataServiceV2
// Runtime: CluauppLibs.DataService
//
// Real surface (not Get(player, path)):
//   DataService.Server / DataService.Client / DataService.Paths / DataService.Enum
//   local data = Server:WaitFor(player)
//   data:Get(Paths.Currencies.Coins)
//   data:GetChangedSignal(path):Connect(function(newValue, oldValue) end)

class DataPath {};
class DataProfile {};

struct DataBufferStats {
	double Bytes;
	double Messages;
	double LastPacketBytes;
	double LastUtilization;
};

struct OrderedListOptions {
	string key;
	string order;
	int limit;
};

struct DataOrderList {
	string Asc;
	string Desc;
};

struct DataServiceEnum {
	DataOrderList OrderList;
};

template <typename T>
struct DataServiceOptions {
	T Template;
	string StoreName;
	bool UseMock;
	string KeyPrefix;
	LuaArray<DataPath> Exclude;
	bool StrictPaths;
	bool AutoCreateMissingTables;
};

class Data {
public:
	RBXScriptSignal Changed;
	bool Destroyed;

	template <typename T>
	T Get();
	template <typename T>
	T Get(DataPath path);

	template <typename T>
	T GetPersisted();
	template <typename T>
	T GetPersisted(DataPath path);

	template <typename T>
	T GetTransient();
	template <typename T>
	T GetTransient(DataPath path);

	bool HasTransient();
	bool HasTransient(DataPath path);

	template <typename T>
	void Set(DataPath path, T value);
	template <typename T>
	void SetTransient(DataPath path, T value);

	template <typename T>
	T Update(DataPath path, T (*fn)(T current));
	template <typename T>
	T UpdateTransient(DataPath path, T (*fn)(T current));

	void ClearTransient();
	void ClearTransient(DataPath path);

	template <typename T>
	void ArrayInsert(DataPath path, T value);
	template <typename T>
	void ArrayInsert(DataPath path, T value, int index);
	template <typename T>
	void ArrayInsertTransient(DataPath path, T value);
	template <typename T>
	void ArrayInsertTransient(DataPath path, T value, int index);

	template <typename T>
	T ArrayRemove(DataPath path, int index);
	template <typename T>
	T ArrayRemoveTransient(DataPath path, int index);

	template <typename V>
	LuaArray<V> GetOrderedList(DataPath path, OrderedListOptions options);
	template <typename V>
	LuaArray<V> GetOrderedListWithPriority(DataPath path, string key);
	template <typename V>
	LuaArray<V> GetOrderedListWithPriority(DataPath path, string key, string order);

	RBXScriptSignal GetChangedSignal(DataPath path);
	RBXScriptSignal GetPathChangedSignal(DataPath path);
	RBXScriptSignal GetIndexChangedSignal(DataPath path);
	RBXScriptSignal GetArrayInsertedSignal(DataPath path);
	RBXScriptSignal GetArrayRemovedSignal(DataPath path);

	DataPath Typed(DataPath path);
	void Destroy();
};

class DataServiceServer {
public:
	DataPath Paths;
	template <typename T>
	DataServiceServer* Init(DataServiceOptions<T> options);
	Data* WaitFor(Player* player);
	Data* Get(Player* player);
	bool HasData(Player* player);
	DataProfile* GetProfile(Player* player);
	DataBufferStats* GetBufferStats();
	DataBufferStats* GetBufferStats(Player* player);
	void Destroy();
};

class DataServiceClient {
public:
	DataPath Paths;
	Data* Init();
	Data* WaitForData();
	Data* Get();
	DataBufferStats* GetBufferStats();
	void Destroy();
};

class DataService {
public:
	static DataServiceServer Server;
	static DataServiceClient Client;
	static DataPath Paths;
	static DataServiceEnum Enum;
};
