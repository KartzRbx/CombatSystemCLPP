#pragma once

// evaera/roblox-lua-promise — vendored into CluauppLibs.Promise
// C++ Then/Catch/Await/Cancel map onto andThen/catch/await/cancel.
class Promise {
public:
	Promise(void (*executor)());
	template <typename T>
	static Promise* resolve(T value);
	static Promise* reject(string err);
	static Promise* delay(double seconds);
	static Promise* try_(void (*callback)());
	static Promise* all(LuaArray<Promise*> list);
	static Promise* race(LuaArray<Promise*> list);
	static Promise* retry(void (*callback)(), int times);
	Promise* Then(void (*ok)());
	Promise* Catch(void (*fail)());
	Promise* Finally(void (*callback)());
	Promise* andThen(void (*ok)());
	Promise* catch_(void (*fail)());
	Promise* finally(void (*callback)());
	template <typename T>
	T Await();
	template <typename T>
	T await();
	void Cancel();
	void cancel();
	string GetStatus();
	string getStatus();
};
