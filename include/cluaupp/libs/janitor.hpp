#pragma once

// howmanysmall/Janitor — vendored into CluauppLibs.Janitor
class Janitor {
public:
	bool CurrentlyCleaning;
	bool SuppressInstanceReDestroy;
	bool UnsafeThreadCleanup;
	Janitor();
	template <typename T>
	T Add(T object);
	template <typename T>
	T Add(T object, bool callDirectly);
	template <typename T>
	T Add(T object, string methodName);
	template <typename T>
	T Add(T object, string methodName, string index);
	template <typename T>
	T AddObject(T constructor);
	template <typename P>
	P AddPromise(P promise);
	template <typename P>
	P AddPromise(P promise, string index);
	Janitor* Remove(string index);
	Janitor* RemoveNoClean(string index);
	Janitor* RemoveList(string index);
	Janitor* RemoveListNoClean(string index);
	template <typename T>
	T Get(string index);
	void GetAll();
	void Cleanup();
	void Destroy();
	RBXScriptConnection LinkToInstance(Instance* object);
	RBXScriptConnection LinkToInstance(Instance* object, bool allowMultiple);
	Janitor* LinkToInstances(Instance* object);
	static bool Is(Instance* value);
	static bool Is(string value);
	static bool instanceof(Instance* value);
};
