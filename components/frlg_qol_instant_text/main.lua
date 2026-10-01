return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "mode", label = "TEXT", type = "choice", default = "instant",
      choices = { { "INSTANT", "instant" }, { "FAST", "fast" } } },
  })
  local Message = require("src.ui.game3.message")
  local function reveal()
    if not Message.open then return end
    if mod.options:get("mode") == "instant" then Message.skipReveal()
    else Message._speedIdx = 2 end
  end
  api.wrap(Message, "show", function(previous, ...)
    local result = previous(...)
    reveal()
    return result
  end)
  api.wrap(Message, "advance", function(previous, ...)
    local result = previous(...)
    reveal()
    return result
  end)
end
