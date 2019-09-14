local PhysicsReferences = require("world/physicsReferences")
local Timer = require("timer")

local Shield = class()

function Shield:__create(body)
	self.partLocations = {}
	self.body = body
	self.collidedFixtures = {}
	self.timer = Timer(5)
	self.health = 0
	self.healRate = 0
	self.maxHealth = 0
end

function Shield:createFixture()
	if self.fixture then self.fixture:destroy() end
	local count, x, y = 0, 0, 0
	for part, location in pairs(self.partLocations) do
		count = count + 1
		x = x + location[1]
		y = y + location[2]
	end

	if count == 0 then
		self.fixture = nil
		return
	end

	x = x / count
	y = y / count
	self.center = {x, y}
	self.radius = 5 * math.sqrt(count)
	self.healRate = count
	self.maxHealth = count * 10
	local shape = love.physics.newCircleShape(x, y, self.radius + 1)
	self.fixture = love.physics.newFixture(self.body, shape)
	self.fixture:setUserData(self)
	PhysicsReferences.setFixtureType(self.fixture, "shield")
end

function Shield:addPart(part)
	self.partLocations[part] = {part.location[1], part.location[2]}
	self:createFixture()
end

function Shield:removePart(part)
	self.partLocations[part] = nil
	self:createFixture()
end

function Shield:collision(_, fixture)
	self.collidedFixtures[fixture] = self:test(fixture)
end

function Shield:endCollision(_, fixture)
	self.collidedFixtures[fixture] = nil
end

function Shield:test(fixture)
	local x, y = self.body:getWorldPoints(unpack(self.center))
	local radius = math.min(self.health, self.radius)
	local fixtureX, fixtureY = fixture:getBody():getPosition()
	local dx = fixtureX - x
	local dy = fixtureY - y
	return (dx * dx) + (dy * dy) < radius * radius
end

function Shield:damage(_, d)
	self.health = self.health - d
	if self.health < 0 then
		self.health = 0
	end
end

function Shield:draw()
	local x, y = self.body:getWorldPoints(unpack(self.center))
	local radius = math.min(math.sqrt(5 * self.health), self.radius)

	if radius < 1 then return end

	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(31/255, 63/255, 143/255, 95/255)
	love.graphics.circle("fill", x, y, radius)
	love.graphics.setColor(r, g, b, a)
end

function Shield:update(dt)
	if self.timer:ready(dt) then
		self.health =math.min(self.health + self.healRate, self.maxHealth)
	end

	for fixture, value in pairs(self.collidedFixtures) do
		if self:test(fixture) and not value then
			fixture:getUserData():collision(fixture, self.fixture)
		end
	end
end

return Shield
