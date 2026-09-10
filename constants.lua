-- Stonks Constants
-- Central location for all magic numbers and configuration values
local api = require("api")

local Constants = {
	-- Map center point and coordinate conversion
	DEV_MODE = false,  -- Set to true to enable dev/debug UI controls and test data
	addonName = "Stonks",
	folderPath = api.baseDir .. "/Stonks/",
	
	-- Overlay text styling
	overlay = {
		fontSize = 10,
		heightOffset = -2,
		height = 14,
	},

	buildingNames = {
		"Solar",
		"Lunar",
		"Stellar",
		"Scarecrow",
		"Smelter",
		"Sawmill",
		"Masonry",
		"Leatherwork",
		"Gazebo",
		"Cottage",
		"Farm",
		"Miner's",
		"Treehouse",
		"House",
		"Solarium",
		"Fellowship",
		"Chateau",
		"Terrace",
		"Manor",
		"Loom",
		"Table",
	}
}

return Constants
