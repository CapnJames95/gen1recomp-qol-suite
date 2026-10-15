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
    local Sem = require("src.core.game3.field_semantics")
    local expires = tonumber(Sem.getVar(session, "repelSteps")) == 1
    previous(session, game)
    -- The engine may decline to tick Repel in a facility. Only prompt after
    -- the native counter actually expires, using the same source of truth.
    if expires and tonumber(Sem.getVar(session, "repelSteps")) == 0 and candidate(session) then
      Steps.queueEvent({ run = function(onDone)
        local id = candidate(session)
        if not id or not api.active() then onDone() return end
        local screen, completed
        local function done()
          if completed then return end
          completed = true
          onDone()
        end
        local function answer(reuse)
          -- api.choose removes the menu layer without calling screen.close.
          -- Complete the native step event explicitly, just as B/back does.
          local ok, err = pcall(function()
            if reuse and api.active() and Bag.get(session.bag, id) > 0 then
              Use.useField(session, session.bag, id)
            end
          end)
          screen.close()
          if not ok then error(err, 0) end
        end
        screen = api.menu("Use " .. Items.displayName(id) .. "?", {
          { label = "NO", choose = function() answer(false) end },
          { label = "YES", choose = function() answer(true) end },
        }, done)
      end })
    end
  end)
end
