#pragma once

// Buffer-packed RemoteEvent / RemoteFunction. Names are unique per game.
class NetEvent {
public:
	void Fire(Player* player);
	template <typename A>
	void Fire(Player* player, A a);
	template <typename A, typename B>
	void Fire(Player* player, A a, B b);
	template <typename A, typename B, typename C>
	void Fire(Player* player, A a, B b, C c);
	void FireAll();
	template <typename A>
	void FireAll(A a);
	template <typename A, typename B>
	void FireAll(A a, B b);
	void FireServer();
	template <typename A>
	void FireServer(A a);
	template <typename A, typename B>
	void FireServer(A a, B b);
	void On(void (*callback)());
};

class NetFunction {
public:
	void On(void (*callback)());
	template <typename R>
	R Invoke(Player* player);
	template <typename R, typename A>
	R Invoke(Player* player, A a);
	template <typename R>
	R InvokeServer();
	template <typename R, typename A>
	R InvokeServer(A a);
};

namespace Net {
	NetEvent* Event(string name);
	NetFunction* Function(string name);
}
