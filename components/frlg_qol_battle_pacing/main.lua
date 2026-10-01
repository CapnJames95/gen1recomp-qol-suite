return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Anim = require("src.core.game3.battle.anim")
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "hp", label = "INSTANT HP", type = "toggle", default = true },
    { key = "exp", label = "INSTANT EXP", type = "toggle", default = true },
  })
  api.wrap(Anim, "tweenHp", function(previous, side, fromHp, toHp, maxHp, options)
    local copied = api.copy(options)
    if mod.options:get("hp") then copied.instant = true end
    return previous(side, fromHp, toHp, maxHp, copied)
  end)
  api.wrap(Anim, "tweenExp", function(previous, side, fromRatio, toRatio, options)
    local copied = api.copy(options)
    if mod.options:get("exp") then copied.instant = true end
    return previous(side, fromRatio, toRatio, copied)
  end)
end
