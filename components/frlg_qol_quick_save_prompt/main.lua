return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Save = require("src.ui.game3.save_menu")
  api.wrap(Save, "confirm", function(previous, ...)
    if Save._phase == "confirm" and Save.cursor == 1 then Save._phase = "overwrite" end
    return previous(...)
  end)
end
