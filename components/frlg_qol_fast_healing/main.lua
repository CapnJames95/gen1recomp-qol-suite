return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  local api = Support.new(mod)
  local Heal = require("src.core.game3.pokecenter_heal")
  local Audio = require("src.core.game3.audio")
  local stepping
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "factor", label = "ANIMATION", type = "choice", default = 4,
      choices = { { "2X", 2 }, { "4X", 4 }, { "8X", 8 } } },
    { key = "wait_jingle", label = "WAIT FOR JINGLE", type = "toggle", default = false },
  })
  api.wrap(Audio, "isFanfareFinished", function(previous)
    if stepping and Heal._fx == stepping and stepping.state == 6
        and not mod.options:get("wait_jingle") then return true end
    return previous()
  end)
  api.wrap(Heal, "step", function(previous)
    local factor = mod.options:get("factor")
    if factor ~= 2 and factor ~= 4 and factor ~= 8 then factor = 4 end
    for iteration = 1, factor do
      if not Heal.isActive() then break end
      local saved = stepping
      stepping = Heal._fx
      local ok, failure = pcall(previous)
      stepping = saved
      if not ok then error(failure, 0) end
    end
  end)
end
