local GridTable = require("gridTable")
local Settings = require("settings")
local StructureMath = require("structureMath")

local Structure = {}
Structure.__index = Structure

function Structure.create(worldInfo, location, shipTable)
	local self = {}
	setmetatable(self, Structure)

	self.worldInfo = worldInfo
	self.physics = worldInfo.physics
	self.events = worldInfo.events
	self.maxDiameter = 1
	self.size = 1
	self.isDestroyed = false

	if not shipTable.parts then
		self.gridTable = GridTable.create()
		self.gridTable:index(0, 0, shipTable)
		shipTable:setLocation({0, 0, 1})
		if shipTable.type ~= "generic" then
			self.corePart = shipTable
		end
	else
		self.gridTable = shipTable.parts
	end

	local x = location[1]
	local y = location[2]
	if shipTable.corePart then
		if shipTable.corePart.type == "control" then
			self.body = love.physics.newBody(self.physics, x, y, "dynamic")
			self.body:setAngularDamping(1)
			self.body:setLinearDamping(.1)
			self.type = "ship"
		elseif shipTable.corePart.type == "anchor" then
			self.body = love.physics.newBody(self.physics, x, y, "static")
			self.type = "anchor"
		end
		self.corePart = shipTable.corePart
	else
		self.body = love.physics.newBody(self.physics, x, y, "dynamic")
		self.body:setAngularDamping(.1)
		self.body:setLinearDamping(0.01)
		self.type = "generic"
	end
	if location[3] then
		self.body:setAngle(location[3])
	end
	if location[4] and location[5] then
		self.body:setLinearVelocity(location[4], location[5])
	end
	if location[6] then
		self.body:setAngularVelocity(location[6])
	end
	self.body:setUserData(self)

	local function callback(part, structure)
		structure:addFixture(part)
	end
	self.gridTable:loop(callback, self)

	return self
end

function Structure:postCreate(references)
	if self.corePart and self.corePart.postCreate then
		self.corePart:postCreate(references)
	end
end

-- The table set to nill.

function Structure:destroy()
	self.body:destroy()
	self.isDestroyed = true
end

-------------------------
-- Setters and Getters --
-------------------------
function Structure:getLocation()
	return self.body:getX(), self.body:getY(), self.body:getAngle()
end

function Structure:getTeam()
	if self.corePart then
		return self.corePart:getTeam()
	end
	return 0
end

function Structure:getSaveData(references)
	local team = self:getTeam()
	local leader
	if self.corePart and self.corePart.leader then
		leader = references[self.corePart.leader]
	end

	return {team, leader}
end

-------------------------------
-- Adding and Removing Parts --
-------------------------------
function Structure:addFixture(part)
	local shape = love.physics.newRectangleShape(part.location[1],
												 part.location[2],
												 1, 1)
	local fixture = love.physics.newFixture(self.body, shape)
	part:setFixture(fixture)
end

-- Add one part to the structure.
-- x, y are the coordinates in the structure.
-- orientation is the orientation of the part according to the structure.
function Structure:addPart(part, x, y, orientation)
	part:setLocation({x, y, orientation})
	self:addFixture(part)
	--self:calculateSize(x, y)
	self:recalculateSize()

	self.gridTable:index(x, y, part)
end

-- If there are no more parts in the structure,
-- then mark this structure for destruction.
function Structure:removePart(part)
	if part == self.corePart then
		self.corePart = nil
	end

	local x, y = unpack(part.location)
	self.gridTable:index(x, y, nil, true)
	part.fixture:destroy()

--	for i,fixture in ipairs(self.body:getFixtureList()) do
--		if not fixture:isDestroyed() then
--			return
--		end
--	end

	local parts = self.gridTable:loop()
	if #parts <= 0 then
		self.isDestroyed = true
	end
end

-----------------------------------------
-- Adding and removing groups of parts --
-----------------------------------------

-- Annex another structure into this one.
-- ** After calling this method, the annexed structure will be destroyed and
-- should be removed from any tables it is referenced in.
-- Parameters:
-- annexee is the structure to annex
-- annexeePart is the block that will connect to this structure
-- orientation is the side of annexee to attach
-- structurePart is the block to connect the structure to
-- side is the side of structurePart to add the annexee to
function Structure:annex(annexee, annexeePart, annexeePartSide,
				structurePart, structurePartSide)
	local structureOffsetX = structurePart.location[1]
	local structureOffsetY = structurePart.location[2]

	local annexeeX = annexeePart.location[1]
	local annexeeY = annexeePart.location[2]

	local annexeeSide = StructureMath.toDirection(annexeePartSide + annexeePart.location[3])
	local structureSide = StructureMath.toDirection(structurePartSide + structurePart.location[3])

	local annexeeBaseVector = {annexeeX, annexeeY, annexeeSide}
	local structureVector = {structureOffsetX, structureOffsetY, structureSide}

	structureVector = StructureMath.addUnitVector(structureVector, structureSide)
	local baseVector = StructureMath.subtractVectors(structureVector, annexeeBaseVector)

	local parts = annexee.gridTable:loop()
	for i=1,#parts do
		self:annexPart(annexee, parts[i], baseVector)
	end
end

function Structure:annexPart(annexee, part, baseVector)
	local annexeeVector = {part.location[1], part.location[2], part.location[3]}
	local netVector = StructureMath.sumVectors(baseVector, annexeeVector)

	local x, y = unpack(netVector)
	if self.gridTable:index(x, y) then
		annexee:disconnectPart(part)
	else
		annexee:removePart(part)
		self:addPart(part, netVector[1], netVector[2], netVector[3])
	end
end

function Structure:testConnection(testPoints)
	local keep = {}
	for _, location in ipairs(testPoints) do
		local x, y = unpack(location)
		 if self.gridTable:index(x, y) then
			if x ~= 0 or y ~= 0 then
				table.insert(keep, {x, y})
			end
		end
	end
	testPoints = keep
	local testedPoints = {}
	local points = {}
	local clusters = {}
	local tested = GridTable.create()
	if self.gridTable:index(0, 0) then
		tested:index(0, 0, 2)
	end

	while #testPoints ~= 0 do
		table.insert(points, table.remove(testPoints))
		local testedPointX, TestedPointY = unpack(points[1])
		tested:index(testedPointX, TestedPointY, 1)

		while #points ~= 0 do
			local point = table.remove(points)
			table.insert(testedPoints, point)
			for i = 1,4 do
				local newPoint = StructureMath.addUnitVector(point, i)

				local part = self.gridTable:index(unpack(point))
				local newPart = self.gridTable:index(unpack(newPoint))
				if part and newPart then
					local partSide = (i - part.location[3]) % 4 + 1
					local partConnect = part.connectableSides[partSide]
					local newPartSide = (i - newPart.location[3] + 2) % 4 + 1
					local newPartConnect = newPart.connectableSides[newPartSide]
					if partConnect and newPartConnect then
						for j = #testPoints, 1, -1 do
							local ax, ay = unpack(newPoint)
							local bx, by = unpack(testPoints[j])
							if ax == bx and ay == by then
								table.remove(testPoints, j)
							end
						end
						local value = tested:index(unpack(newPoint))

						if value == 2 then
							for _, testedPoint in ipairs(testedPoints) do
								local x, y = unpack(testedPoint)
								tested:index(x, y, 2)
							end

							for _, eachPoint in ipairs(points) do
								local x, y = unpack(eachPoint)
								tested:index(x, y, 2)
							end
							testedPoints = {}
							points = {}
							break
						elseif value ~= 1 then
							local x, y = unpack(newPoint)
							tested:index(x, y, 1)
							table.insert(points, newPoint)
						end
					end
				end
			end
		end

		if #testedPoints ~= 0 then
			table.insert(clusters, testedPoints)
			testedPoints = {}
		end
	end

	for _, group in ipairs(clusters) do
		for j, location in ipairs(group) do
			group[j] = self.gridTable:index(unpack(location))
		end
	end

	return clusters
end

function Structure:recalculateSize()
	self.maxDiameter = 1
	local function callback(part, self, x, y)
		x = math.abs(x)
		y = math.abs(y)
		local d = math.max(x, y) + x + y + 1
		if self.maxDiameter < d then
			self.maxDiameter = d
			self.size = math.ceil(self.maxDiameter * 0.5625/
								  Settings.chunkSize)
		end
	end

	self.gridTable:loop(callback, self)
end

-- Part was disconnected or destroyed remove part and handle outcome.
function Structure:disconnectPart(part)
	if #self.gridTable:loop() == 1 and not part.isDestroyed then
		return
	end

	self:removePart(part)
	if self.isDestroyed and part.isDestroyed then
		return
	end

	local savedPart
	if not part.isDestroyed then
		savedPart = part
	end


	local points = {}
	for i = 1,4 do
		table.insert(points, StructureMath.addUnitVector(part.location, i))
	end
	local clusters = self:testConnection(points)
	local structureList

	if savedPart then
		if not self.corePart then
			structureList = clusters
			table.insert(structureList, {savedPart})
		else
			structureList = {{savedPart}}
			for _, group in ipairs(clusters) do
				for _, eachPart in ipairs(group) do
					table.insert(structureList[1], eachPart)
				end
			end
		end
	else
		structureList = clusters
	end

	for i = 1, #structureList do
		local partList = structureList[i]
		local basePart = partList[1]
		local baseVector = basePart.location
		local location = {basePart:getWorldLocation()}

		baseVector = StructureMath.subtractVectors({0,0,3}, baseVector)

		local structure = GridTable.create()
		for _, eachPart in ipairs(partList) do
			local partVector = {unpack(eachPart.location)}
			local netVector = StructureMath.sumVectors(baseVector, partVector)
			if eachPart ~= savedPart then
				self:removePart(eachPart)
			end
			eachPart:setLocation(netVector)
			structure:index(netVector[1], netVector[2], eachPart)

		end

		local newStructure = {"structures", location, {parts = structure}}
		table.insert(self.events.create, newStructure)
	end


	self:recalculateSize()
end

-------------------------
-- Mangement functions --
-------------------------

-- Restructure input from player or output from ai
-- make the information easy for parts to handle.
function Structure:command(orders)
	local perpendicular = 0
	local parallel = 0
	local rotate = 0
	local shoot = false

	for _, order in ipairs(orders) do
		if order == "forward" then parallel = parallel + 1 end
		if order == "back" then parallel = parallel - 1 end
		if order == "strafeLeft" then perpendicular = perpendicular - 1 end
		if order == "strafeRight" then perpendicular = perpendicular + 1 end
		if order == "right" then rotate = rotate - 1 end
		if order == "left" then rotate = rotate + 1 end
		if order == "shoot" then shoot = true end
	end

	local engines = {0, 0, 0, 0, parallel, perpendicular, rotate}

	if parallel > 0 then
		engines[1] = 1
	elseif parallel < 0 then
		engines[3] = 1
	end

	if perpendicular > 0 then
		engines[4] = 1
	elseif perpendicular < 0 then
		engines[2] = 1
	end

	local commands = {engines = engines, guns = {shoot = shoot}}

	return commands
end

-- Handle commands
-- Update each part
function Structure:update(dt, worldInfo)
	local partsInfo = {}
	if self.corePart then
		local body = self.body
		local vX, vY = body:getLinearVelocity()
		local location = {body:getX(), body:getY(), body:getAngle(),
					  vX, vY, body:getAngularVelocity()}
		partsInfo = self:command(self.corePart:getOrders(location, worldInfo))
	end

	local function callback(part, inputs) --(part, inputs, x, y)
		part:update(unpack(inputs))
	end

	self.gridTable:loop(callback, {dt, partsInfo})
end

return Structure
