#pragma once

// SirMallard/Iris — vendored into CluauppLibs.Iris
class IrisWidget {};
class IrisState {};

namespace Iris {
	void Init();
	void Init(Instance* parent);
	void Shutdown();
	void Connect(void (*callback)());
	bool Window(string title);
	void End();
	void Text(string text);
	bool Button(string label);
	bool SmallButton(string label);
	bool Checkbox(string label);
	bool Checkbox(string label, bool* value);
	IrisWidget InputNum(string label);
	IrisWidget InputText(string label);
	IrisWidget SliderNum(string label);
	IrisWidget DragNum(string label);
	bool Tree(string label);
	bool CollapsingHeader(string label);
	bool Combo(string label);
	bool RadioButton(string label, bool value);
	bool TabBar();
	bool Tab(string label);
	bool Table(int columns);
	void SameLine();
	void Separator();
	void Indent();
	void Unindent();
	template <typename T>
	IrisState State(T initial);
	void PushConfig(IrisState style);
	void PopConfig();
	void ForceRefresh();
	void Append(GuiObject* instance);
}
