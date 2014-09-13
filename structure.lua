local Part = require("part")
require("util")

local Structure = {}
Structure.__index = Structure

function Structure.create(part, world, x, y)
	local self = {}
	setmetatable(self, Structure)

	if part.type == "player" then
		self.body = love.physics.newBody(world, x, y, "dynamic")
		self.body:setAngularDamping(1)
		self.body:setLinearDamping(0.5)
		self.thrust = part.thrust
		self.torque = part.torque
	elseif part.type == "anchor" then
		self.body = love.physics.newBody(world, x, y, "static")
	else
		self.body = love.physics.newBody(world, x, y, "dynamic")
		self.body:setAngularDamping(0.2)
		self.body:setLinearDamping(0.1)
	end

	self.type = part.type -- type can be "player", "anchor", or "generic"
	self.parts = {part}
	self.partCoords = { {x = 0, y = 0} }
	self.fixtures = {love.physics.newFixture(self.body, part.shape)}

	return self
end

-- Merge another structure into this one.
-- structure is the structure to merge
-- connectionPointA is the block that will connect to this this structure
-- connectionPointB is the block to connect the structure to
-- side is the side of connectionPointB to add the structure to
function Structure:merge(structure, connectionPointA, connectionPointB, side)
	local aIndex = structure:findPart(connectionPointA)
	local bIndex = self:findPart(connectionPointB)
	local relX, relY

	if side == "right" then
		relX =
			self.body:getX() + self.partCoords[bIndex].x +
			connectionPointB.width/2 + connectionPointA.width/2 -
			structure.partCoords[aIndex].x
		relY =
			self.body:getY() + self.partCoords[bIndex].y -
			structure.partCoords[aIndex].y
	end

	local absX, absY = computeAbsCoords(relX, relY, self.body:getAngle())
	structure:fly(absX, absY, self.body:getAngle())

	for i, part in ipairs(structure.parts) do
		self:addPart(part, structure.body:getX() + structure.partCoords[i].x,
		             structure.body:getY() + structure.partCoords[i].y)
		structure:removePart(part)
	end
end

function Structure:addPart(part, x, y)
	local x1, y1, x2, y2, x3, y3, x4, y4 = part.shape:getPoints()
	local width = math.abs(x1 - x3)
	local height = math.abs(y1 - y3)
	local relX = x - self.body:getX()
	local relY = y - self.body:getY()
	local shape = love.physics.newRectangleShape(relX, relY, width, height)
	local fixture = love.physics.newFixture(self.body, shape)
	table.insert(self.parts, part)
	table.insert(self.partCoords, {x = relX, y = relY})
	table.insert(self.fixtures, fixture)
end

function Structure:addHinge()
end

-- Check if a part is in this structure.
-- If it is, return the index of the part.
-- If it is not, return nil.
function Structure:findPart(query)
	for i, part in ipairs(self.parts) do
		if part == query then
			return i
		end
	end

	return nil
end

function Structure:removePart(part)
	i = self:findPart(part)
	if i then
		self.fixtures[i]:destroy()
		table.remove(self.parts, i)
		table.remove(self.partCoords, i)
		table.remove(self.fixtures, i)
	end
end

function Structure:destroy()
	self.fixtures[1]:destroy()

	table.remove(self.parts, 1)
	table.remove(self.partCoords, 1)
	table.remove(self.fixtrues, 1)
end

-- move the structure to a particular location smoothly
function Structure:fly(x, y, angle)
	-- right now this is anything but smooth...
	self.body:setPosition(x, y)
	self.body:setAngle(angle)
end

-- Find the absolute coordinates of a part given the x and y offset values of
-- the part and the absolute coordinates and angle of the structure it is in.
function Structure:getAbsPartCoords(index)
	local x, y = computeAbsCoords(
		self.partCoords[index].x,
		self.partCoords[index].y,
		self.body:getAngle())

	return self.body:getX() + x, self.body:getY() + y
end

function Structure:draw()
	for i, part in ipairs(self.parts) do
		local x, y = self:getAbsPartCoords(i)
		part:draw(x, y,	self.body:getAngle(), playerX, playerY)
	end
end

-- todo:
-- don't call this function from love.update()
function Structure:handleInput()
	if love.keyboard.isDown("w") then
		self.body:applyForce(
			self.thrust * math.cos(self.body:getAngle() - math.pi/2),
			self.thrust * math.sin(self.body:getAngle() - math.pi/2))
	end
	if love.keyboard.isDown("s") then
		self.body:applyForce(
			-self.thrust * math.cos(self.body:getAngle() - math.pi/2),
		    -self.thrust * math.sin(self.body:getAngle() - math.pi/2))
	end
	if love.keyboard.isDown("j") then
		self.body:applyForce(
			-self.thrust * math.cos(self.body:getAngle()),
			-self.thrust * math.sin(self.body:getAngle()))
	end
	if love.keyboard.isDown("k") then
		self.body:applyForce(
			self.thrust * math.cos(self.body:getAngle()),
			self.thrust * math.sin(self.body:getAngle()))
	end
	if love.keyboard.isDown("a") then
		self.body:applyTorque(-self.torque)
	end
	if love.keyboard.isDown("d") then
		self.body:applyTorque(self.torque)
	end
end

return Structure