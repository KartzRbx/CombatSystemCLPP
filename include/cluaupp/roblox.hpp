#pragma once
// Cluaupp — full Roblox API for IntelliSense.
// Source: official client dump + datatypes from create.roblox.com
// The compiler ignores #include and emits real Luau (Vector3.new, Instance.new, :GetPlayers, ...).

#include <cluaupp/generated/enums.hpp>
#include <cluaupp/datatypes.hpp>
#include <cluaupp/generated/instances.hpp>
#include <cluaupp/libs.hpp>

template <typename T>
T* GetService();

template <typename T>
T* GetService(Instance* game_);

extern DataModel* game;
extern Workspace* workspace;
extern LuaSourceContainer* script;

void print(string message);
void warn(string message);
void error(string message);

struct cout {
	static void print(string message);
	static void warn(string message);
	static void error(string message);
	static void ping(string message);
	static void endl();
	cout& operator<<(string value);
	cout& operator<<(int value);
	cout& operator<<(double value);
	cout& operator<<(bool value);
} cout;

struct cerr {
	cerr& operator<<(string value);
	cerr& operator<<(int value);
} cerr;

const int endl = 0;
double tick();
double time();
void wait(double seconds = 0);
void spawn(void (*callback)());
void delay(double seconds, void (*callback)());
