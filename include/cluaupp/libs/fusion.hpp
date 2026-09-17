#pragma once

// dphfox/Fusion 0.4 — vendored into CluauppLibs.Fusion
class FusionScope {};
class FusionState {};
class FusionKey {};
class FusionObserver {};
class FusionContextual {};

namespace Fusion {
	FusionScope scoped();
	FusionKey New(string className);
	template <typename T>
	FusionState Value(T initial);
	FusionState Computed(void (*callback)());
	FusionObserver Observer(FusionState value);
	template <typename T>
	T peek(FusionState value);
	FusionKey Hydrate(Instance* instance);
	FusionKey Children();
	FusionKey Child();
	FusionKey OnEvent(string eventName);
	FusionKey OnChange(string propertyName);
	FusionKey Out(string propertyName);
	FusionKey Attribute(string name);
	FusionKey AttributeChange(string name);
	FusionKey AttributeOut(string name);
	FusionKey Tag(string name);
	FusionState Tween(FusionState value, TweenInfo tweenInfo);
	FusionState Spring(FusionState value, double speed, double damping);
	FusionState ForKeys(FusionState input, void (*processor)());
	FusionState ForValues(FusionState input, void (*processor)());
	FusionState ForPairs(FusionState input, void (*processor)());
	void doCleanup(Instance* task);
	FusionScope deriveScope(FusionScope scope);
	FusionScope innerScope(FusionScope scope);
	void insert(FusionScope scope, Instance* task);
	template <typename T>
	FusionContextual Contextual(T defaultValue);
	void Safe(void (*callback)());
}
