--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Keep = require(ReplicatedStorage.CluauppLibs.Keep)
const TemplateData = require(ReplicatedStorage.Shared.Constants.Datas.TemplateData)

-- DataBoot.server.clpp:6
const function init()
	local playerData = TemplateData()

	if not (playerData) then
		return
	end

	Keep.Server:Init({ Template = playerData, StoreName = "PlayerData", UseMock = true })
end

init()
