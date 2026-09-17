#pragma once

// TheNexusAvenger/Module3D — ViewportFrame adorn, vendored into CluauppLibs.Module3D
class Model3D {
public:
	Model* Object3D;
	GuiObject* AdornFrame;
	Camera* Camera;
	bool Visible;
	void Update();
	void SetCFrame(CFrame newCF);
	CFrame GetCFrame();
	void SetDepthMultiplier(double multiplier);
	double GetDepthMultiplier();
	void SetActive(bool active);
	bool GetActive();
	void Destroy();
	void End();
};

class Module3D {
public:
	static Model3D* new_(Instance* model);
	static Model3D* Attach3D(GuiObject* frame, Instance* model);
};
