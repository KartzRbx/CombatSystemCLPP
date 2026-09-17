#pragma once

// nightcycle/spring — Fraktality-style damped spring, vendored into CluauppLibs.Spring
class Spring {
public:
	double Damping;
	double Frequency;
	double Goal;
	double Position;
	double Velocity;
	Spring(double dampingRatio, double frequency, double position);
	void Set(double goal);
	double Get();
	void Step(double dt);
	void Impulse(double velocity);
	void SetGoal(double target);
	double Update(double dt);
};
