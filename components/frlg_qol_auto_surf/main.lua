return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Player = require("src.core.game3.player")
  local Field = require("src.core.game3.field")
  local FieldMoves = require("src.core.game3.field_moves")
  local Message = require("src.ui.game3.message")
  local interaction

  api.wrap(Field, "interact", function(previous, game)
    game = game or Field._game
    local input = game and game.input
    local saved = interaction
    interaction = input and input.wasPressed and input:wasPressed("a")
      and api.session() and not Player.biking and {} or nil
    local ok, result = pcall(previous, game)
    if ok and not result and interaction and Player.underwater
        and require("src.core.GameVersion").get()=="emerald" then
      ok,result=pcall(require("src.core.game3.dive").tryEmerge)
    end
    interaction = saved
    if not ok then error(result, 0) end
    return result
  end)

  if require("src.core.GameVersion").get() == "emerald" then
    local Space=require("src.core.game3.scripting.space")
    local Actions=assert(load(mod:read("field_actions.lua")))()
    local labels={EventScript_CutTree="CUT",EventScript_RockSmash="ROCK_SMASH",
      EventScript_StrengthBoulder="STRENGTH",EventScript_UseSurf="SURF",
      EventScript_UseWaterfall="WATERFALL",EventScript_UseDive="DIVE",EventScript_UseDiveUnderwater="DIVE"}
    api.wrap(Space,"startScript",function(previous,key,...)
      local game=Field._game or require("src.core.game3.runtime")._game
      local input=game and game.input
      if (interaction or (input and input:wasPressed("a"))) and not Field.locked and not Player.moving then
        for label,move in pairs(labels) do
          if key==Space.scriptKey(label) then
            local ctx=Actions.context(api.session())
            local mon,slot
            if ctx then mon,slot=FieldMoves.partyMoveUser(ctx.party,move) end
            if mon then
              ctx.mon=mon
              local result=FieldMoves.fromMenu(move,ctx)
              if result and result.ok then
                -- Keep Emerald's native script, field effects, encounter rolls,
                -- object flags and usage counters. Only skip successful prompts.
                local source=Space.vm and Space.vm.scripts[key]
                local rewritten,confirmed={},false
                for _,row in ipairs(source or {}) do
                  if row.op=='checkpartymove' then
                    rewritten[#rewritten+1]={op='setvar',var=0x800D,value=slot}
                    rewritten[#rewritten+1]={op='setvar',var=0x8004,value=mon.species}
                  elseif row.op=='callstd' and (row.std or row[1])==5 then
                    confirmed=true
                    rewritten[#rewritten+1]={op='setvar',var=0x800D,value=1}
                  elseif not (confirmed and row.op=='callstd' and (row.std or row[1])==4) then
                    rewritten[#rewritten+1]=row
                  end
                end
                if confirmed then
                  local quick='qol:field-action:'..label
                  Space.vm.scripts[quick]=rewritten
                  return previous(quick,...)
                end
              end
            end
          end
        end
      end
      return previous(key,...)
    end)
  end

  -- Only intercept successful native A-button offers, preserving target priority,
  -- badge/move gates and execution payloads (including HM Field Kit providers).
  local actions = {
    trySurfOW = "surf", tryCutOW = "cut_tree", tryStrengthOW = "strength",
    tryRockSmashOW = "rock_smash", tryWaterfallOW = "waterfall",
  }
  for method, action in pairs(actions) do
    api.wrap(FieldMoves, method, function(previous, context)
      local result = previous(context)
      if interaction then
        interaction.move = result and result.ok and result.action == action and result.ask and result or nil
      end
      return result
    end)
  end

  api.wrap(Message, "show", function(previous, text, ...)
    local move = interaction and interaction.move
    if move and text == move.ask then
      interaction.move = nil
      local payload = api.copy(move)
      payload.ask, payload.text = nil, nil
      return Field.executeFieldMove(payload)
    end
    return previous(text, ...)
  end)
end
