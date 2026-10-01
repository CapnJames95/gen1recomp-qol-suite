return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Game = require("src.core.Game3")
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "factor", label = "SPEED", type = "choice", default = 4,
      choices = { { "2X", 2 }, { "4X", 4 }, { "8X", 8 } } },
    { key = "key", label = "HOLD KEY", type = "choice", default = "f9",
      choices = { { "F9", "f9" }, { "RIGHT CTRL", "rctrl" }, { "LEFT CTRL", "lctrl" }, { "F6", "f6" } } },
    { key = "pad", label = "HOLD BUTTON", type = "choice", default = "leftstick",
      choices = { { "OFF", "off" }, { "L3", "leftstick" }, { "R3", "rightstick" },
        { "LEFT SHOULDER", "leftshoulder" }, { "RIGHT SHOULDER", "rightshoulder" } } },
  })
  local touchSession
  mod.exports.setTouchHeld=function(down)
    touchSession=down and api.active() and api.session() or nil
  end
  local function held()
    if touchSession and touchSession==api.session() then return true end
    touchSession=nil
    if love and love.keyboard and love.keyboard.isDown(mod.options:get("key")) then return true end
    local button = mod.options:get("pad")
    if button and button ~= "off" and love and love.joystick then
      for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() and joystick:isGamepadDown(button) then return true end
      end
    end
    return false
  end
  api.wrap(Game, "logicSpeed", function(previous, game)
    local speed = previous(game)
    if game.session and game.phase == "field" and not game:speedLocked()
        and (not love or not love.window or not love.window.hasFocus or love.window.hasFocus()) and held() then
      return math.max(speed, mod.options:get("factor"))
    end
    return speed
  end)
end
