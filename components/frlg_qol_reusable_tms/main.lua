return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local ItemUse = require("src.core.game3.item_use")
  local Bag = require("src.core.game3.bag")
  local Items = require("src.core.game3.items_data")
  local Learn = require("src.core.game3.battle.learn_move")
  local teaching = 0
  local function scoped(callback, ...)
    teaching = teaching + 1
    local result = { pcall(callback, ...) }
    teaching = teaching - 1
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, 5)
  end
  api.wrap(Bag, "remove", function(previous, bag, id, quantity)
    if teaching > 0 and Items.isTm(id) and not Items.isHm(id) then return true end
    return previous(bag, id, quantity)
  end)
  api.wrap(Learn, "begin", function(previous, options)
    if teaching == 0 or type(options.onDone) ~= "function" then return previous(options) end
    local copied = api.copy(options)
    copied.onDone = function(...) return scoped(options.onDone, ...) end
    return previous(copied)
  end)
  api.wrap(ItemUse, "useTm", function(previous, ...)
    return scoped(previous, ...)
  end)
end
