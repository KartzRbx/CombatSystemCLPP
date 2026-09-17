#pragma once

// Cluaupp VfxUtil — emit / play / stop / clone ParticleEmitters, Beams, Trails, Sounds.
namespace VfxUtil {
	void Emit(Instance* root);
	void Emit(Instance* root, int count);
	void Play(Instance* effect);
	void Stop(Instance* effect);
	Instance* CloneOnto(Instance* template_, Instance* parent);
	void Scale(Instance* root, double factor);
	void DestroyAfter(Instance* root, double lifetime);
	Instance* Burst(Instance* template_, Instance* parent);
}
