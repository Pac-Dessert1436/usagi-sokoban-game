local Game = require("scenes.game")

function _config()
  return { name = "Usagi Sokoban Game", game_id = "com.usagiengine.sokoban" }
end

function _init()
  State = { game = Game.new() }
  State.game:load_level(0)
end

function _update(dt)
  State.game:update(dt)
end

function _draw(dt)
  gfx.clear(gfx.COLOR_BLACK)
  State.game:draw()
end