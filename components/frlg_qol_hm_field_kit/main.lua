return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "illuminate_caves", label = "FULL CAVE LIGHTING", type = "toggle", default = false },
  })
  local api = Support.new(mod)
  local FieldMoves = require("src.core.game3.field_moves")
  local Pokemon = require("src.core.game3.pokemon")
  local Bag = require("src.core.game3.bag")
  local Items = require("src.core.game3.items_data")
  local Map = require("src.core.game3.map")
  local FieldView = require("src.core.game3.field_view")
  local function darkCave()
    local def = Map.currentDef()
    return def and (tonumber(def.cave) or 0) ~= 0
  end
  -- WorldAPI omits the cave flag from its field-action context on older
  -- builds. Fill only the missing context; keep native badge/Flash checks.
  api.wrap(FieldMoves, "fromMenu", function(previous, move, ctx)
    if FieldMoves.normalizeMoveId(move) == FieldMoves.MOVES.FLASH
        and ctx and ctx.isCave == nil and ctx.isDarkCave == nil then
      ctx = api.copy(ctx)
      ctx.isCave = darkCave() and true or false
    end
    if FieldMoves.normalizeMoveId(move) == FieldMoves.MOVES.SWEET_SCENT then
      local Field=require("src.core.game3.field")
      if type(Field.finishSweetScent)~="function" then
        return {ok=false,reason="Sweet Scent needs gen1recomp 0.3.42 or newer."}
      end
      local E=require("src.core.game3.encounters")
      local Player=require("src.core.game3.player")
      local terrain=E.terrainAt(Player.cellX,Player.cellY)
      local areas=E.tableFor(Map.current)
      local area=areas and (terrain=="land" and (areas.land or areas.grass) or terrain=="water" and areas.water)
      if not area then return {ok=false,reason="Stand in encounter grass, a cave or encounter water."} end
    end
    return previous(move, ctx)
  end)
  -- Suppress only the rendered mask. Native Flash state, animations and save
  -- data keep updating normally, so turning this off restores current state.
  api.wrap(FieldView, "flashRadius", function(previous, ...)
    if mod.options:get("illuminate_caves") == true and darkCave() then return nil end
    return previous(...)
  end)
  local function ownsHm(session, itemId)
    local bag = session.bag
    -- Bag.get sanitizes and sorts every pocket. Availability is polled by the
    -- companion, so read native slots without rewriting the bag on each poll.
    -- The Battle Pyramid substitutes its own bag; retain that native rule.
    local Pyramid = session.version == "emerald" and require("src.core.game3.rse.frontier.pyramid")
    if session.version == "emerald" and Pyramid and Pyramid.bagActive(session) then
      return Bag.get(bag, itemId) > 0
    end
    if type(bag.pockets) ~= "table" then return Bag.get(bag, itemId) > 0 end
    for _, slots in pairs(bag.pockets) do
      for _, slot in ipairs(slots) do
        if Items.toNumericId(slot.id) == itemId and (tonumber(slot.qty) or 0) > 0 then
          return true
        end
      end
    end
    return false
  end
  api.wrap(FieldMoves, "partyMoveUser", function(previous, party, move)
    local session = api.session()
    local moveId = FieldMoves.normalizeMoveId(move)
    if not session or party ~= session.party or not session.bag then
      return previous(party, move)
    end
    if moveId == FieldMoves.MOVES.SWEET_SCENT
        and type(require("src.core.game3.field").finishSweetScent)=="function" then
      local mon,slot=previous(party,move)
      if mon then return mon,slot end
      -- Sweet Scent has no HM item or badge: borrow only the presentation user.
      for index,candidate in ipairs(party) do
        if not Pokemon.isEgg(candidate) then return candidate,index-1 end
      end
      return nil,6
    end
    for itemId = 1, 512 do
      if Items.isHm(itemId) and Pokemon.moveFromTmItem(itemId) == moveId then
        -- HM ownership gates even a traded Pokemon that already knows it.
        if not ownsHm(session, itemId) then return nil, 6 end
        local mon, slot = previous(party, move)
        if mon then return mon, slot end
        -- The native animation still needs a real non-egg party member, but
        -- its species does not need to learn the move. Never edit moves/PP.
        for index, candidate in ipairs(party) do
          if not Pokemon.isEgg(candidate) then return candidate, index - 1 end
        end
        return nil, 6
      end
    end
    -- Dig, Teleport and other non-HM moves retain the native learned-move rule.
    return previous(party, move)
  end)

  local Actions=assert(load(mod:read("field_actions.lua"),"@hm_field_kit/field_actions.lua"))()
  local Compat=require("src.mods.Gen3Compat")
  local ItemUse=require("src.core.game3.item_use")
  local function moveRow(id)
    local session=api.session()
    if not session then return end
    local ctx=Actions.context(session)
    if not ctx or not Actions.allowed(id,ctx) then return end
    local mon,slot=FieldMoves.partyMoveUser(session.party,id)
    if not mon then return end
    ctx.mon=mon
    local result=FieldMoves.fromMenu(id,ctx)
    if result and result.ok then return {slot=slot+1} end
  end
  local function useMove(id)
    if Compat.worldBusy() then return api.notice("Finish the current action first.") end
    local row=moveRow(id)
    if not row then return api.notice("Cannot use here.") end
    Actions.execute(api.session(),id,row)
  end
  local function rods()
    local rows={};local session=api.session()
    if not session then return rows end
    for _,name in ipairs({"OLD_ROD","GOOD_ROD","SUPER_ROD"}) do
      local id=Items.toNumericId(name)
      if id and Bag.get(session.bag,id)>0 then
        rows[#rows+1]={label=name:gsub("_"," "),choose=function()
          if Compat.worldBusy() or Bag.get(session.bag,id)<1 or not ItemUse.canFish() then
            return api.notice("Cannot fish here.")
          end
          Actions.execute(session,"rod:"..id,{item=id})
        end}
      end
    end
    return rows
  end
  api.startItem("HM FIELD KIT", function()
    local rows = {}
    for _,id in ipairs({"CUT","SURF","STRENGTH","ROCK_SMASH","WATERFALL","DIVE","FLASH","DIG","TELEPORT","SWEET_SCENT"}) do
      local chosen=id
      if moveRow(id) then rows[#rows+1]={label=id:gsub("_"," "),choose=function()useMove(chosen)end} end
    end
    if #rods()>0 and ItemUse.canFish() then
      rows[#rows+1]={label="FISH",choose=function()api.menu("CHOOSE A ROD",rods())end}
    end
    -- Preserve the existing bicycle shortcut.
    for _,action in ipairs(mod.world:availableFieldActions()) do
      if action.id=="bicycle" then rows[#rows+1]={label=action.label,choose=function()
        local ok,reason=mod.world:useFieldAction("bicycle")
        if not ok then api.notice(tostring(reason or "Cannot use here")) end
      end} end
    end
    if #rows == 0 then rows[1] = { label = "No field action available here" } end
    api.menu("FIELD KIT", rows)
  end)
end
