#pragma once

// nightcycle/display — pretty-print Luau values (Rust Display-style).
// Vendored into CluauppLibs.Display with nightcycle/option bundled.
class DisplayBuilder {};

namespace Display {
	DisplayBuilder* builder();
	string display(string value);
	string display(double value);
	string display(bool value);
	string display(Instance* value);
}
