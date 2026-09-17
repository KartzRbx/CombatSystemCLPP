#pragma once

// UI animator. https://devforum.roblox.com/t/twinkle-free-powerful-ui-animator-module/4512304
namespace Twinkle {
	void Fade(GuiObject* element, bool show);
	void Fade(GuiObject* element, bool show, double speed);
	void FrameSlide(GuiObject* element, bool show);
	void FrameSlide(GuiObject* element, bool show, double speed);
	void FrameZoom(GuiObject* element, bool show);
	void FrameZoom(GuiObject* element, bool show, double speed);
	void FrameBounce(GuiObject* element);
	void FrameBounce(GuiObject* element, double speed);
	void SetButtonStyle(GuiObject* element);
	void SetButtonStyle(GuiObject* element, string hoverType, string pressType, double scalePercent);
}
