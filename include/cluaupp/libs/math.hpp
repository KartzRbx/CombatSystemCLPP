#pragma once

namespace MathUtils {
	double Lerp(double a, double b, double alpha);
	double Map(double value, double inMin, double inMax, double outMin, double outMax);
	double Clamp(double value, double min, double max);
	double Round(double value);
	double Round(double value, int digits);
	double AngleDiff(double a, double b);
	double LerpAngle(double a, double b, double alpha);
	double Random(double min, double max);
	int Weighted(LuaArray<double> weights);
	Vector3 LerpVector(Vector3 a, Vector3 b, double alpha);
}
