#pragma once

// arxkdev/ezVisualz — EasyVisuals, vendored into CluauppLibs.EzVisualz
// Effect.new(gui, "Rainbow", speed, size)
class EzVisualz {
public:
	static EzVisualz* new_(GuiObject* target, string effectType);
	static EzVisualz* new_(GuiObject* target, string effectType, double speed, double size);
	void Play();
	void Pause();
	void Resume();
	void Stop();
	void Destroy();
	GuiObject* UIInstance;
	double Speed;
	double Size;
	bool IsPaused;
};
