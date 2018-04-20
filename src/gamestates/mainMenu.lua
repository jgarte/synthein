local GameState = require("gamestates/gameState")
local LoadGameMenu = require("gamestates/loadGameMenu")
local Suit = require("vendor/suit")
local NewGameMenu = require("gamestates/newGameMenu")

local MainMenu = GameState()

local menuFont
if love.graphics then
	menuFont = love.graphics.newFont(36)
end

function MainMenu.update(dt)
	Suit.layout:reset(love.graphics.getWidth()/2 - 450/2, 250)
	Suit.layout:padding(25, 25)
	button = Suit.Button("New Game", Suit.layout:row(450, 50))
	if button.hit then
			MainMenu.stackQueue:push(NewGameMenu)
	end
	if Suit.Button("Load Game", Suit.layout:row(450, 50)).hit then
			MainMenu.stackQueue:push(LoadGameMenu)
	end
end

function MainMenu.draw()
	local screen_width = love.graphics.getWidth()
	local previousFont = love.graphics.getFont()
	love.graphics.setFont(menuFont)
	love.graphics.print("SYNTHEIN", (screen_width - 200)/2 + 10, 175 , 0, 1, 1, 0, 0, 0, 0)
	love.graphics.setFont(previousFont)

	Suit.draw()
end

function MainMenu.keypressed(key)
	if key == "escape" then love.event.quit() end
end

return MainMenu
