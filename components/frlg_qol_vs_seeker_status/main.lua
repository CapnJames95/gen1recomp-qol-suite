return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  if require("src.core.GameVersion").get() == "emerald" then
    api.startItem("MATCH CALL REMATCHES", function(game)
      local tools=mod.find and mod.find("frlg_qol_hoenn_tools")
      if tools and tools.exports and tools.exports.showRematches then return tools.exports.showRematches(game) end
      local Rematch=require("src.core.game3.rse.rematch")
      local session=api.session()
      local rows={}
      for index=0,Rematch.count()-1 do
        local ids=Rematch.trainerIds(index)
        if ids and ids[1] and Rematch.isTrainerReadyForRematch(session,ids[1]) then
          local pack=require("src.core.game3.scripting.trainers").pack()
          local trainer=pack and pack.trainers and pack.trainers[ids[1]]
          rows[#rows+1]={label=tostring(trainer and trainer.name or ("Trainer "..ids[1]))..": READY"}
        end
      end
      if #rows==0 then rows[1]={label="No rematches ready"} end
      rows[#rows+1]={label="Open PokeNav for trainer locations"}
      api.menu("MATCH CALL",rows)
    end)
    return
  end
  local Items = require("src.core.game3.items_data")
  local Seeker = require("src.core.game3.vs_seeker")
  api.wrap(Items, "description", function(previous, id, ...)
    local text = previous(id, ...)
    local session = api.session()
    if id == Seeker.ITEM_VS_SEEKER and session then
      local charge = Seeker.getBattery(session)
      return charge >= Seeker.MAX_CHARGE and "Battery READY.\nUse near trainers outdoors."
        or ("Battery %d/%d.\nWalk %d more steps."):format(charge, Seeker.MAX_CHARGE,
          Seeker.MAX_CHARGE - charge)
    end
    return text
  end)
end
