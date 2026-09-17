#pragma once

// Prooheckcp/RobloxStateMachine — vendored into CluauppLibs.StateMachine
class StateData {};

class StateMachine {
public:
	static StateMachine* new_(string initial);
	static StateData* LoadDirectory(Instance* directory);
	void ChangeState(string name);
	string GetState();
	string GetCurrentState();
	string GetPreviousState();
	StateData* GetData();
	void ChangeData(string index, string value);
	void ChangeData(string index, double value);
	void ChangeData(string index, bool value);
	void Destroy();
};
