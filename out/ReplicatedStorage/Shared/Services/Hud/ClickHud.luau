--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Gleam = require(ReplicatedStorage.CluauppLibs.Gleam)
const Keep = require(ReplicatedStorage.CluauppLibs.Keep)

export type ClickHud = {
	players: Players,
	me: Player,
	Session: any,
	PointsSource: GleamSource,
	HudGui: ScreenGui,
	PointsLabel: TextLabel,
	ClickButton: TextButton,
	HUD_NAME: string,
	BUTTON_TEXT: string,
	POPUP_TEXT: string,
	POPUP_LIFE: number,
	POPUP_START_OFFSET: number,
	BAR_HEIGHT: number,
	BAR_BOTTOM: number,
	BUTTON_HEIGHT: number,
	BUTTON_COLOR_R: number,
	BUTTON_COLOR_G: number,
	BUTTON_COLOR_B: number,
	BAR_COLOR_R: number,
	BAR_COLOR_G: number,
	BAR_COLOR_B: number,
	SetupClickHud: (self: ClickHud) -> boolean,
	BindCharacter: (self: ClickHud) -> boolean,
	BindKeep: (self: ClickHud) -> boolean,
	BuildHud: (self: ClickHud) -> boolean,
	BindClickButton: (self: ClickHud) -> boolean,
	BindClickAck: (self: ClickHud) -> boolean,
	BindPointsReplication: (self: ClickHud) -> boolean,
	OnCharacterSpawned: (self: ClickHud, character: Model) -> boolean,
	OnClickPressed: (self: ClickHud) -> boolean,
	OnClickAck: (self: ClickHud, points: number, damage: number) -> boolean,
	OnPointsReplicated: (self: ClickHud, points: number) -> boolean,
	RefreshPointsLabel: (self: ClickHud) -> boolean,
	EmitClickPopup: (self: ClickHud) -> boolean,
	CreatePopupLabel: (self: ClickHud) -> TextLabel,
}

const function ClickHud()
	return {
		players = game:GetService("Players"),
		me = nil,
		Session = nil,
		PointsSource = nil,
		HudGui = nil,
		PointsLabel = nil,
		ClickButton = nil,
		HUD_NAME = "ClickHud",
		BUTTON_TEXT = "CLICK",
		POPUP_TEXT = "+1",
		POPUP_LIFE = 0.45,
		POPUP_START_OFFSET = -108,
		BAR_HEIGHT = 96,
		BAR_BOTTOM = -18,
		BUTTON_HEIGHT = 52,
		BUTTON_COLOR_R = 0.92,
		BUTTON_COLOR_G = 0.22,
		BUTTON_COLOR_B = 0.28,
		BAR_COLOR_R = 0.08,
		BAR_COLOR_G = 0.08,
		BAR_COLOR_B = 0.12,
	}
end

return ClickHud
