return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Player = require("src.core.game3.player")
  api.wrap(Player, "canDash", function()
    if require("src.core.game3.profile").active().family == "rse" then
      return not Player.underwater and not Player.runningDisallowed(Player.cellX, Player.cellY)
    end
    return true
  end)
end
