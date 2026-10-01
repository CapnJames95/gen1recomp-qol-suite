return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Steps = require("src.core.game3.step_events")
  local Use = require("src.core.game3.item_use")
  local Bag = require("src.core.game3.bag")
  local Items = require("src.core.game3.items_data")
  local last
  api.wrap(Use, "useField", function(previous, session, bag, id, ...)
    local ok, kind, text = previous(session, bag, id, ...)
    if ok and kind == "repel" then last = id end
    return ok, kind, text
  end)
  local function candidate(session)
    local ids = { last or 0, Items.toNumericId("MAX REPEL") or 0,
      Items.toNumericId("SUPER REPEL") or 0, Items.toNumericId("REPEL") or 0 }
    for _, id in ipairs(ids) do
      if id > 0 and Bag.get(session.bag, id) > 0 then return id end
    end
  end
  api.wrap(Steps, "onRepelStep", function(previous, session, game)
    local repelVar = 0x4020
    if session.version == "emerald" then
      repelVar = require("src.core.game3.constants").of("emerald"):require("vars", "VAR_REPEL_STEP_COUNT")
    end
    local expires = tonumber(session.repelSteps or (session.vars or {})[repelVar]) == 1
    previous(session, game)
    if expires and candidate(session) then
      Steps.queueEvent({ run = function(onDone)
        local id = candidate(session)
        if not id or not api.active() then onDone() return end
        api.menu("Use " .. Items.displayName(id) .. "?", {
          { label = "NO", choose = function() end },
          { label = "YES", choose = function()
            if Bag.get(session.bag, id) > 0 then Use.useField(session, session.bag, id) end
          end },
        }, onDone)
      end })
    end
  end)
end
