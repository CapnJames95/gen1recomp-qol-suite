return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Party = require("src.ui.game3.party_menu")
  local Relearner = require(require("src.core.GameVersion").get()=="emerald" and "src.ui.game3.rse.move_relearner" or "src.ui.game3.move_relearner")
  local Bag = require("src.core.game3.bag")
  local Items = require("src.core.game3.items_data")
  api.wrap(Party, "handleInput", function(previous, input)
    if api.partyReady(Party) and input:wasPressed("start") then
      local session = api.session()
      local big = Items.toNumericId("BIG MUSHROOM")
      local tiny = Items.toNumericId("TINY MUSHROOM")
      local payment, count
      if session.version == "emerald" then
        local heart = Items.toNumericId("HEART SCALE")
        if heart and Bag.get(session.bag, heart) >= 1 then payment, count = heart, 1 end
      elseif tiny and Bag.get(session.bag, tiny) >= 2 then payment, count = tiny, 2
      elseif big and Bag.get(session.bag, big) >= 1 then payment, count = big, 1 end
      if not payment then api.notice(session.version == "emerald" and "Need 1 Heart Scale" or "Need 2 Tiny or 1 Big Mushroom") return end
      local charged = false
      Relearner.show(session.party[Party.cursor], { session = session, onDone = function(learned)
        if learned and not charged then
          Bag.remove(session.bag, payment, count)
          charged = true
        end
      end })
      return
    end
    return previous(input)
  end)
end
