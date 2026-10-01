return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Party = require("src.ui.game3.party_menu")
  local Pokemon = require("src.core.game3.pokemon")
  local Items = require("src.core.game3.items_data")
  api.wrap(Party, "handleInput", function(previous, input)
    if api.partyReady(Party) and input:wasPressed("l") then
      local rows = {}
      for _, mon in ipairs(api.session().party) do
        local item = tonumber(mon.item or mon.heldItem) or 0
        rows[#rows + 1] = { label = Pokemon.displayMonName(mon) }
        rows[#rows + 1] = { label = item > 0 and Items.displayName(item) or "(no held item)" }
      end
      api.menu("PARTY HELD ITEMS", rows)
      return
    end
    return previous(input)
  end)
  local Help = require("src.ui.game3.help_system")
  local Stack = require("src.ui.game3.stack")
  api.wrap(Help, "update", function(previous, game)
    local top = Stack.top()
    if not Help.isOpen() and top and top.mod == Party and api.partyReady(Party)
        and game.input and game.input:wasPressed("l") then
      Party.handleInput(game.input)
      return true
    end
    return previous(game)
  end)
end
