local map_data = require("scenes.map_data")

local SPRITE = {
  BOX_ON_TARGET = 1,
  REGULAR_BOX = 2,
  TARGET = 3,
  OBSTACLE = 4,
  WALKABLE_TILE = 5,
  PLAYER_LEFT = 6,
  PLAYER_RIGHT = 7,
  PLAYER_UP = 8,
  PLAYER_DOWN = 9,
}

local TILE_SIZE = 16

local Game = {}
Game.__index = Game

function Game.new()
  local self = setmetatable({}, Game)
  self.floor = 0
  self.total_moves = 0
  self.level_moves = 0
  self.level_offset = { x = 0, y = 0 }
  self.original_player_pos = { x = 0, y = 0 }
  self.original_boxes = {}
  self.player_pos = { x = 0, y = 0 }
  self.boxes = {}
  self.goals = {}
  self.walls = {}
  self.floor_tiles = {}
  self.level_completed = false
  self.player_direction = "right"
  self.delay_timer = 0
  self.delay_action = nil
  return self
end

function Game:get_level_name()
  if self.floor == 0 then
    return "Opening"
  else
    return "Floor " .. self.floor
  end
end

function Game:get_total_floors()
  local count = 0
  for k, _ in pairs(map_data) do
    if k ~= "Opening" then
      count = count + 1
    end
  end
  return count
end

function Game:load_level(level)
  music.stop()
  self.level_completed = false
  self.level_moves = 0
  self.boxes = {}
  self.goals = {}
  self.walls = {}
  self.floor_tiles = {}
  self.original_boxes = {}

  local level_name = self:get_level_name()
  local level_data = map_data[level_name]

  local level_width = #level_data[1] * TILE_SIZE
  local level_height = #level_data * TILE_SIZE
  self.level_offset = {
    x = (usagi.GAME_W - level_width) // 2,
    y = (usagi.GAME_H - level_height) // 2
  }

  for y = 1, #level_data do
    for x = 1, #level_data[y] do
      local cell = level_data[y][x]
      local pos = { x = x - 1, y = y - 1 }

      if cell == "w" then
        table.insert(self.walls, pos)
      elseif cell == "b" then
        table.insert(self.boxes, pos)
        table.insert(self.original_boxes, { x = pos.x, y = pos.y })
        table.insert(self.floor_tiles, pos)
      elseif cell == "g" then
        table.insert(self.goals, pos)
      elseif cell == "B" then
        table.insert(self.boxes, pos)
        table.insert(self.original_boxes, { x = pos.x, y = pos.y })
        table.insert(self.goals, pos)
        table.insert(self.floor_tiles, pos)
      elseif cell == "p" then
        self.player_pos = pos
        self.original_player_pos = { x = pos.x, y = pos.y }
        table.insert(self.floor_tiles, pos)
      else
        table.insert(self.floor_tiles, pos)
      end
    end
  end

  if level > 0 then
    music.loop("main_theme")
  end
end

function Game:reset_level()
  self.player_pos = { x = self.original_player_pos.x, y = self.original_player_pos.y }
  self.boxes = {}
  for _, box in ipairs(self.original_boxes) do
    table.insert(self.boxes, { x = box.x, y = box.y })
  end
  self.level_moves = 0
  self.level_completed = false
end

function Game:contains_pos(list, pos)
  for _, p in ipairs(list) do
    if p.x == pos.x and p.y == pos.y then
      return true
    end
  end
  return false
end

function Game:find_box_index(pos)
  for i, box in ipairs(self.boxes) do
    if box.x == pos.x and box.y == pos.y then
      return i
    end
  end
  return -1
end

function Game:handle_movement(move_dir)
  local level_name = self:get_level_name()
  local profile = map_data[level_name]
  local max_row_idx = #profile[1] - 1
  local max_col_idx = #profile - 1

  local function wrap_position(input)
    local wrapped = { x = input.x, y = input.y }
    if wrapped.x < 0 then wrapped.x = max_row_idx end
    if wrapped.x > max_row_idx then wrapped.x = 0 end
    if wrapped.y < 0 then wrapped.y = max_col_idx end
    if wrapped.y > max_col_idx then wrapped.y = 0 end
    return wrapped
  end

  local new_player_pos = { x = self.player_pos.x + move_dir.x, y = self.player_pos.y + move_dir.y }
  local wrapped_player_pos = wrap_position(new_player_pos)

  if self:contains_pos(self.walls, wrapped_player_pos) then
    return
  end

  local box_index = self:find_box_index(wrapped_player_pos)
  if box_index >= 0 then
    local new_box_pos = { x = wrapped_player_pos.x + move_dir.x, y = wrapped_player_pos.y + move_dir.y }
    local wrapped_box_pos = wrap_position(new_box_pos)

    if self:contains_pos(self.walls, wrapped_box_pos) or self:contains_pos(self.boxes, wrapped_box_pos) then
      return
    end

    self.boxes[box_index] = wrapped_box_pos
    sfx.play("box_pushed")
  end

  self.player_pos = wrapped_player_pos
  self.level_moves = math.min(self.level_moves + 1, 999)
end

function Game:check_level_complete()
  for _, goal in ipairs(self.goals) do
    if not self:contains_pos(self.boxes, goal) then
      return false
    end
  end
  return true
end

function Game:get_move_count_info(is_victory)
  local right_half
  if is_victory then
    if self.total_moves >= 1000 then
      right_half = "At least 1000"
    else
      right_half = string.format("%3d", self.total_moves)
    end
    return "Total moves taken: " .. right_half
  else
    if self.total_moves >= 1000 then
      right_half = "Total >= 1000"
    else
      right_half = string.format("Total = %3d", self.total_moves)
    end
    return string.format("Moves = %3d    %s", self.level_moves, right_half)
  end
end

function Game:update(dt)
  if not self.level_completed then
    local move_dir = nil

    if input.pressed(input.UP) then
      move_dir = { x = 0, y = -1 }
      self.player_direction = "up"
    elseif input.pressed(input.DOWN) then
      move_dir = { x = 0, y = 1 }
      self.player_direction = "down"
    elseif input.pressed(input.LEFT) then
      move_dir = { x = -1, y = 0 }
      self.player_direction = "left"
    elseif input.pressed(input.RIGHT) then
      move_dir = { x = 1, y = 0 }
      self.player_direction = "right"
    end

    if input.pressed(input.KEY_X) or input.pressed(input.BTN2) then
      self:reset_level()
    end

    if move_dir then
      self:handle_movement(move_dir)
    end
  end

  if self.delay_action then
    self.delay_timer -= dt
    if self.delay_timer <= 0 then
      self.delay_action()
      self.delay_action = nil
    end
  end

  if not self.level_completed and self:check_level_complete() then
    music.stop()
    self.level_completed = true

    if self.floor == 0 then
      self.level_moves = 0
      music.play("game_start")
    else
      music.play("level_cleared")
    end

    self.total_moves = math.min(self.total_moves + self.level_moves, 999)

    local delay = self.floor == 0 and 7 or 5
    self.delay_timer = delay
    self.delay_action = function()
      self.floor += 1
      local level_key = self:get_level_name()
      if map_data[level_key] then
        self:load_level(self.floor)
      else
        music.stop()
        music.play("victory_theme")
        self.floor = -1
      end
    end
  end
end

function Game:draw()
  for _, pos in ipairs(self.floor_tiles) do
    gfx.spr(SPRITE.WALKABLE_TILE, self.level_offset.x + pos.x * TILE_SIZE, self.level_offset.y + pos.y * TILE_SIZE)
  end

  for _, pos in ipairs(self.goals) do
    gfx.spr(SPRITE.TARGET, 
            self.level_offset.x + pos.x * TILE_SIZE, 
            self.level_offset.y + pos.y * TILE_SIZE)
  end

  for _, pos in ipairs(self.walls) do
    gfx.spr(SPRITE.OBSTACLE,
            self.level_offset.x + pos.x * TILE_SIZE,
            self.level_offset.y + pos.y * TILE_SIZE)
  end

  for _, pos in ipairs(self.boxes) do
    gfx.spr(self:contains_pos(self.goals, pos) and SPRITE.BOX_ON_TARGET or SPRITE.REGULAR_BOX,
            self.level_offset.x + pos.x * TILE_SIZE,
            self.level_offset.y + pos.y * TILE_SIZE)
  end

  local player_sprite = SPRITE.PLAYER_RIGHT
  if self.player_direction == "left" then
    player_sprite = SPRITE.PLAYER_LEFT
  elseif self.player_direction == "up" then
    player_sprite = SPRITE.PLAYER_UP
  elseif self.player_direction == "down" then
    player_sprite = SPRITE.PLAYER_DOWN
  end
  gfx.spr(player_sprite, 
          self.level_offset.x + self.player_pos.x * TILE_SIZE,
          self.level_offset.y + self.player_pos.y * TILE_SIZE)

  local first_line = ""
  local second_line = ""

  if self.floor == -1 then
    gfx.text("CONGRATULATIONS! All levels completed!", 10, 5, gfx.COLOR_YELLOW)
    gfx.text(self:get_move_count_info(true), 10, 20, gfx.COLOR_PEACH)
    gfx.text("Thanks for playing. Please close the game window.", 10, 150, gfx.COLOR_WHITE)
  elseif self.floor == 0 then
    gfx.text("Arrow keys to move, X/BTN2 to restart the level,", 10, 150, gfx.COLOR_WHITE)
    gfx.text("and ENTER to pause or exit at any time.", 10, 165, gfx.COLOR_WHITE)
    if self.level_completed then
      first_line = "Great! Let's begin the adventure!"
      second_line = self:get_move_count_info(false)
    else
      first_line = "Welcome to the Sokoban game!"
      second_line = "Push the box to the target to begin."
    end
  else
    second_line = self:get_move_count_info(false)

    if self.floor == 6 and not self.level_completed then
      gfx.text("NEW POWER UNLOCKED: SCREEN WRAPPING!", 10, 150, gfx.COLOR_BLUE)
      gfx.text("Move off an edge to teleport to the opposite side.", 10, 165, gfx.COLOR_WHITE)
    end

    if self.level_completed and self.floor + 1 > self:get_total_floors() then
      first_line = "Excellent! Finishing the game."
    elseif self.level_completed then
      first_line = "Excellent! Heading to Floor " .. (self.floor + 1) .. "."
    else
      first_line = "You're now at Floor " .. self.floor .. " of " .. self:get_total_floors() .. " (X/BTN2=restart)"
    end
  end

  if self.floor >= 0 then
    gfx.text(first_line, 10, 5, gfx.COLOR_WHITE)
    gfx.text(second_line, 10, 20, gfx.COLOR_WHITE)
  end
end

return Game