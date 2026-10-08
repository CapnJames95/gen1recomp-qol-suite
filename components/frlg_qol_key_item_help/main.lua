return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  local api = Support.new(mod)
  local Bag = require("src.core.game3.bag")
  local Items = require("src.core.game3.items_data")
  local FieldRuntime = require("src.core.game3.runtime")
  local pending = {}
  local bagNotes = {
    [360] = "BICYCLE: Ride outdoors.\nRegister for quick use.",
    [361] = "TOWN MAP: View region maps.\nFly still needs its usual\nrequirements.",
    [362] = "VS SEEKER: Outdoor rematches.\nWalk 100 steps to recharge.\nNot all trainers accept.",
    [261] = "ITEMFINDER: Use in the field\nto find nearby hidden items.",
    [262] = "OLD ROD: Face water, then\nuse it to fish.",
    [263] = "GOOD ROD: Face water to fish\nfor a different selection.",
    [264] = "SUPER ROD: Face water to fish\nfor a different selection.",
    [350] = "POKE FLUTE: Wake SNORLAX.\nIn battle, wakes sleeping\nPOKEMON.",
    [359] = "SILPH SCOPE: Identifies\nghosts automatically when\nthe story requires it.",
  }
  local notes = {
    [360] = "BICYCLE: use outdoors to ride. Register it for your field shortcut.",
    [361] = "TOWN MAP: view Kanto and unlocked island maps. Fly still needs its normal requirements.",
    [362] = "VS SEEKER: use near outdoor trainers. Recharge by walking 100 steps; not every trainer accepts.",
    [261] = "ITEMFINDER: use in the field to look for nearby hidden items.",
    [262] = "OLD ROD: face water and use it to fish.",
    [263] = "GOOD ROD: face water and use it to fish for a different selection.",
    [264] = "SUPER ROD: face water and use it to fish for a different selection.",
    [350] = "POKE FLUTE: use beside a sleeping Snorlax. In battle it wakes sleeping Pokemon.",
    [359] = "SILPH SCOPE: identifies ghosts automatically when the story requires it.",
  }
  if require("src.core.game3.profile").active().family=="rse" then
    notes,bagNotes={},{}
    local descriptions={
      MACH_BIKE="MACH BIKE: Build speed for cracked floors and muddy slopes.",
      ACRO_BIKE="ACRO BIKE: Use hops and wheelies for special paths.",
      POKEBLOCK_CASE="POKEBLOCK CASE: Feed Pokeblocks for contest condition or use them in the Safari Zone.",
      WAILMER_PAIL="WAILMER PAIL: Water planted berries. Can also reveal an unusual tree.",
      ITEMFINDER="ITEMFINDER: Search nearby hidden items.",
      OLD_ROD="OLD ROD: Face water to fish.",GOOD_ROD="GOOD ROD: Face water to fish.",SUPER_ROD="SUPER ROD: Face water to fish.",
      EON_TICKET="EON TICKET: Southern Island access via Lilycove harbor when available.",
      AURORA_TICKET="AURORA TICKET: Birth Island access via Lilycove harbor.",
      MYSTIC_TICKET="MYSTIC TICKET: Navel Rock access via Lilycove harbor.",
    }
    local version=require('src.core.GameVersion').get()
    if version=='ruby' or version=='sapphire' then
      descriptions.WAILMER_PAIL='WAILMER PAIL: Water planted berries.'
      descriptions.AURORA_TICKET=nil;descriptions.MYSTIC_TICKET=nil
    end
    for name,text in pairs(descriptions) do
      local id=Items.toNumericId(name)
      if id then notes[id],bagNotes[id]=text,text end
    end
  end
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "popup", label = "ACQUISITION HELP", type = "toggle", default = true },
  })
  api.wrap(Items, "description", function(previous, id)
    return bagNotes[Items.toNumericId(id)] or previous(id)
  end)
  api.wrap(Bag, "add", function(previous, bag, id, quantity)
    local session, numeric = api.session(), Items.toNumericId(id)
    local first = Bag._modBikeExchange ~= bag and session and session.bag == bag and notes[numeric] and Bag.get(bag, numeric) == 0
    local ok, added = previous(bag, id, quantity)
    if first and ok and mod.options:get("popup") and Bag.get(bag, numeric) > 0 then
      pending[#pending + 1] = { session = session, item = numeric }
    end
    return ok, added
  end)
  mod.hooks:wrap("input.step", function(nextHook, game, dt)
    local result = nextHook(game, dt)
    if not api.active() then pending = {} return result end
    local session = api.session()
    while pending[1] and pending[1].session ~= session do table.remove(pending, 1) end
    if not pending[1] or not mod.options:get("popup") then pending = {} return result end
    local Space = require("src.core.game3.scripting.space")
    local Player = require("src.core.game3.player")
    if game.phase ~= "field" or game.session ~= session or FieldRuntime.uiBusy()
        or require("src.core.game3.field").locked or Player.moving or Player.boulderPush
        or require("src.core.game3.battle").isActive()
        or (Space.vm and Space.vm:isRunning())
        or (Space._immediateVm and Space._immediateVm:isRunning()) then return result end
    local row = table.remove(pending, 1)
    if Bag.has(session.bag, row.item, 1) then api.notice(notes[row.item]) end
    return result
  end)
end
