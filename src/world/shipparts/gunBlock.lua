-- Component
local Gun = require("world/shipparts/gun")

local GunBlock = class(require("world/shipparts/part"))

function GunBlock:__create()
	self.image = love.graphics.newImage("res/images/gun.png")
	self.width = self.image:getWidth()
	self.height = self.image:getHeight()

	self.modules["gun"] = Gun()

	-- GunBlocks can only connect to things on their bottom side.
	self.connectableSides[1] = false
	self.connectableSides[2] = false
	self.connectableSides[4] = false

	return self
end

return GunBlock
