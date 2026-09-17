#pragma once

// Blockzez/RobloxFormatNumber — vendored into CluauppLibs.FormatNumber
// Abbreviate / Comma / Compact are Cluaupp helpers over Simple.FormatCompact.
class FormatNumberMain {};
class FormatNumberSimple {};

namespace FormatNumber {
	string Abbreviate(double value);
	string Abbreviate(double value, int digits);
	string Comma(double value);
	string Compact(double value);
	FormatNumberMain* Main();
	FormatNumberSimple* Simple();
}
