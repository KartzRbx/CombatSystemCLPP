#pragma once

// evaera/Cmdr — vendored into CluauppLibs.Cmdr (server). Client: Cmdr.CmdrClient
class CmdrType {};
class CmdrCommand {};
class CmdrRegistry {};
class CmdrDispatcher {};

namespace Cmdr {
	void RegisterDefaultCommands();
	void RegisterHook(string name, void (*callback)());
	void RegisterType(string name, CmdrType* typeDefinition);
	void RegisterCommand(CmdrCommand* commandDefinition);
	CmdrRegistry* Registry();
	CmdrDispatcher* Dispatcher();
}
