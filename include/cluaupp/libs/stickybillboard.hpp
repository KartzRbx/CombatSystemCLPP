#pragma once

// Cluaupp StickyBillboard — BillboardGui that stays on an adornee.
class StickyBillboard {
public:
	static StickyBillboard* new_(Instance* adornee, GuiObject* gui);
	void SetText(string text);
	void SetEnabled(bool enabled);
	void SetMaxDistance(double distance);
	void Destroy();
	Instance* Adornee;
	GuiObject* Gui;
	BillboardGui* Billboard;
};
