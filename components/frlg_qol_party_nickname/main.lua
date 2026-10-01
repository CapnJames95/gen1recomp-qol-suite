return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Party = require("src.ui.game3.party_menu")
  local Pokemon = require("src.core.game3.pokemon")
  local Naming = require("src.ui.game3.naming")
  local Oam = require("src.core.game3.oam")
  local namingState
  api.wrap(Oam, "buildOamBuffer", function(previous, ...)
    local buffer = previous(...)
    if not namingState or not Naming.openFlag or Naming._state ~= namingState then return buffer end
    -- The party remains open underneath Naming. Its OBJ sprites are rendered
    -- separately from the hidden party background, so suppress only those IDs.
    local owned = {}
    for _, slot in pairs(Party._oam or {}) do
      for _, key in ipairs({ "mon", "ball", "status", "item" }) do
        if slot[key] ~= nil then owned[slot[key]] = true end
      end
    end
    if Party._summaryIcon ~= nil then owned[Party._summaryIcon] = true end
    local filtered = {}
    for _, sprite in ipairs(buffer) do
      if not owned[sprite._id] then filtered[#filtered + 1] = sprite end
    end
    Oam._buffer = filtered
    return filtered
  end)
  api.wrap(Party, "handleInput", function(previous, input)
    if api.partyReady(Party) and input:wasPressed("select") then
      local session = api.session()
      local mon = session.party[Party.cursor]
      Naming.open({ template = "NICKNAME", title = "NICKNAME", maxLen = 10,
        species = mon.species, personality = mon.personality,
        seed = Pokemon.displayMonName(mon), session = session,
        onDone = function(name)
          if api.active() and api.session() == session and session.party[Party.cursor] == mon
              and not Pokemon.isEgg(mon) and type(name) == "string" and name:match("%S") then
            mon.nickname = name
          end
        end })
      namingState = Naming._state
      return
    end
    return previous(input)
  end)
end
