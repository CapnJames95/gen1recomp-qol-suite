return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Held = require("src.core.game3.battle.held_items")
  local State = require("src.core.game3.battle.state")
  local Battle = require("src.core.game3.battle")
  local Bag = require("src.core.game3.bag")
  local Items = require("src.core.game3.items_data")
  local pending = {}
  mod.events:on("battle.started", function() pending = {} end)
  api.wrap(Held, "consume", function(previous, adapter, battler)
    local item = Held.itemOf(battler)
    local state = Battle.getState()
    local mon = State.partyMon(battler)
    local session = api.session()
    local slot
    if state and not state.link and not state.spectate and battler.side == "player"
        and Items.pocketOf(item) == "BERRY_POUCH" then
      for index, candidate in ipairs(state.playerParty or {}) do
        if candidate == mon then slot = index break end
      end
    end
    local result = previous(adapter, battler)
    if slot and Held.itemOf(battler) == 0 and session and session.party[slot] then
      pending[slot] = { item = item, mon = session.party[slot], session = session }
    end
    return result
  end)
  mod.events:on("battle.ended", function()
    if api.active() then
      local session = api.session()
      for slot, row in pairs(pending) do
        local mon = session and session.party[slot]
        if session == row.session and mon == row.mon
            and (tonumber(mon.item or mon.heldItem) or 0) == 0
            and Bag.get(session.bag, row.item) > 0 then
          if Bag.remove(session.bag, row.item, 1) then
            mon.item, mon.heldItem = row.item, row.item
          end
        end
      end
    end
    pending = {}
  end)
end
