return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Summary = require("src.ui.game3.summary_menu")
  local Data = require("src.core.game3.summary_data")
  local Pokemon = require("src.core.game3.pokemon")
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "values", label = "SHOW IV/EV", type = "toggle", default = false },
  })
  local stats = {
    { "HP", "hp", nil }, { "ATK", "atk", "atk" }, { "DEF", "def", "def" },
    { "SPEED", "spe", "spd" }, { "SP. ATK", "spa", "spAtk" }, { "SP. DEF", "spd", "spDef" },
  }
  local function rowsFor(mon)
    local nature, name = Data.nature(mon)
    local rows = { { label = "Nature: " .. tostring(name) } }
    for _, stat in ipairs(stats) do
      local multiplier = stat[3] and Data.natureStatModifier(nature, stat[3]) or 1
      local effect = multiplier > 1 and "+10%" or multiplier < 1 and "-10%" or "neutral"
      local label = stat[1] .. ": " .. effect
      if mod.options:get("values") then
        label = label .. (" IV %d / EV %d"):format((mon.ivs or {})[stat[2]] or 0,
          (mon.evs or {})[stat[2]] or 0)
      end
      rows[#rows + 1] = { label = label }
    end
    local ability = tonumber(mon.abilityId or mon.ability)
      or Pokemon.abilityId(Pokemon.speciesOf(mon), mon.personality)
    rows[#rows + 1] = { label = "Ability: " .. tostring(Pokemon.abilityName(ability)) }
    return rows
  end
  mod.exports.rowsFor = rowsFor
  local function handle(previous, input)
    local S=Summary._nativeDelegate or Summary
    local mon = (S._party or {})[S._cursor]
    if S.open and S._mode ~= "select_move" and S._mode~=2 and S._mode~=3 and not S._enemyParty
        and not (S._opts and S._opts.enemyParty) and not S._fade and not S._pageTask and not S._reload
        and not (S._slide and S._slide.active) and mon and not Pokemon.isEgg(mon)
        and not require("src.core.game3.battle").isActive() and input:wasPressed("select") then
      api.menu(Pokemon.displayMonName(mon), rowsFor(mon))
      return
    end
    return previous(input)
  end
  api.wrap(Summary,"handleInput",handle)
  local version=require('src.core.GameVersion').get()
  if version=='ruby' or version=='sapphire' then api.wrap(require('src.ui.game3.rs.summary_menu'),'handleInput',handle)end
end
