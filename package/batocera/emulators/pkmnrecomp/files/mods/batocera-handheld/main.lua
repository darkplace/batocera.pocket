-- Batocera handheld: L2 = GB aspect lock, R2 = 2X speed toggle.
-- Wraps Game/Game2 so analog triggers do not also cycle the full speed ladder.
return function(mod)
  local held = { left = false, right = false }

  local function persist(game)
    if type(game.writeOptions) == "function" then
      game:writeOptions()
    elseif type(game.persistOptions) == "function" then
      if game.save and game.options then
        game.save.options = game.options
      end
      game:persistOptions()
    end
  end

  local function optionsOf(game)
    if game.save and type(game.save.options) == "table" then
      return game.save.options
    end
    if type(game.options) == "table" then
      return game.options
    end
    return nil
  end

  local function toggleAspect(game)
    local ok, FaithfulRes = pcall(require, "src.core.FaithfulRes")
    local opts = optionsOf(game)
    if not ok or not opts then
      return
    end
    local cur = tonumber(opts.faithfulRes) or 0
    opts.faithfulRes = cur > 0 and 0 or 1
    FaithfulRes.apply(opts.faithfulRes)
    persist(game)
  end

  local function toggleSpeed2x(game)
    local ok, GameSpeed = pcall(require, "src.core.GameSpeed")
    local opts = optionsOf(game)
    if not ok or not opts then
      return
    end
    local function flip(key)
      local cur = GameSpeed.clamp(opts[key] or 1)
      opts[key] = (cur == 1) and 2 or 1
    end
    if opts.speedOverworld ~= nil or opts.speedBattle ~= nil then
      flip("speedOverworld")
      flip("speedBattle")
      flip("speedMenu")
    else
      flip("speed")
    end
    persist(game)
  end

  local function onTrigger(game, which, isDown)
    if isDown and not held[which] then
      if which == "left" then
        toggleAspect(game)
      else
        toggleSpeed2x(game)
      end
    end
    held[which] = isDown and true or false
  end

  local function wrapGamepad(G)
    if type(G) ~= "table" then
      return
    end
    if type(G.gamepadpressed) == "function" then
      local inner = G.gamepadpressed
      function G:gamepadpressed(joystick, button)
        if button == "lefttrigger" then
          onTrigger(self, "left", true)
          return
        end
        if button == "righttrigger" then
          onTrigger(self, "right", true)
          return
        end
        return inner(self, joystick, button)
      end
    end
    if type(G.gamepadreleased) == "function" then
      local inner = G.gamepadreleased
      function G:gamepadreleased(joystick, button)
        if button == "lefttrigger" then
          onTrigger(self, "left", false)
          return inner(self, joystick, button)
        end
        if button == "righttrigger" then
          onTrigger(self, "right", false)
          return inner(self, joystick, button)
        end
        return inner(self, joystick, button)
      end
    end
    if type(G.gamepadaxis) == "function" then
      local inner = G.gamepadaxis
      function G:gamepadaxis(joystick, axis, value)
        if axis == "lefttrigger" then
          onTrigger(self, "left", (tonumber(value) or 0) > 0.5)
        elseif axis == "righttrigger" then
          onTrigger(self, "right", (tonumber(value) or 0) > 0.5)
        end
        return inner(self, joystick, axis, value)
      end
    end
  end

  for _, name in ipairs({ "src.core.Game", "src.core.Game2" }) do
    local ok, G = pcall(require, name)
    if ok then
      wrapGamepad(G)
    end
  end

  mod.exports.version = "1.0.0"
end
