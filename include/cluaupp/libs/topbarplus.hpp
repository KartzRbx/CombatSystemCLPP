#pragma once

// 1ForeverHD/TopbarPlus — vendored into CluauppLibs.TopbarPlus (class Icon)
class IconTheme {};

class Icon {
public:
	static Icon* new_();
	Icon* setName(string name);
	Icon* setLabel(string text);
	Icon* setImage(string image);
	Icon* setEnabled(bool enabled);
	Icon* setOrder(int order);
	Icon* setWidth(int offset);
	Icon* align(string leftCenterOrRight);
	Icon* setLeft();
	Icon* setMid();
	Icon* setRight();
	Icon* bindEvent(string eventName, void (*callback)());
	Icon* bindToggleItem(GuiObject* gui);
	Icon* modifyTheme(IconTheme* modifications);
	Icon* setTheme(IconTheme* theme);
	Icon* notify();
	Icon* clearNotices();
	Icon* select();
	Icon* deselect();
	Icon* autoDeselect(bool enabled);
	void Destroy();
};
