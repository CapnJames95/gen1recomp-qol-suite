return function(mod)
  local E={}
  local Runtime=require('src.core.game3.runtime')
  local Mods=require('src.mods.Runtime')
  local owner=Mods.events
  function E.active(session)
    local s=Runtime.getSession()
    return owner==Mods.events and mod.options:get('enabled')~=false and s~=nil
      and (not session or s==session) and (s.version=='firered' or s.version=='leafgreen' or s.version=='emerald' or s.version=='ruby' or s.version=='sapphire')
  end
  function E.ready(session)
    if not E.active(session) then return false,'Load an active FireRed, LeafGreen or Emerald game.' end
    local game=E.game or Runtime._game
    if not game or game.phase~='field' then return false,'Return to the field first.' end
    local Space=require('src.core.game3.scripting.space')
    if require('src.core.game3.battle').isActive() or require('src.core.game3.battle_transition').isActive()
      or require('src.core.game3.field').locked or require('src.core.game3.player').moving
      or require('src.core.game3.warp').isBusy() or require('src.ui.game3.fade').isActive()
      or (Space.vm and Space.vm:isRunning()) or (Space._immediateVm and Space._immediateVm:isRunning())
      or (game.speedLocked and game:speedLocked()) then return false,'Finish the battle, movement or dialogue first.' end
    return true
  end
  function E.wrap(target,name,handler)
    assert(type(target[name])=='function','Unsupported engine: '..name)
    target.__partyAssistants=target.__partyAssistants or {}
    local key=mod.id..':'..name
    local rec=target.__partyAssistants[key]
    if not rec then
      rec={previous=target[name]};target.__partyAssistants[key]=rec
      target[name]=function(...)
        if rec.active() then return rec.handler(rec.previous,...) end
        return rec.previous(...)
      end
    end
    rec.active,rec.handler=E.active,handler
  end
  function E.start(label,show)
    mod.hooks:wrap('ui.start_menu.items',function(next,game,items)
      local rows=next(game,items)
      if type(rows)~='table' or not E.active() then return rows end
      for _,row in ipairs(rows) do if row.id==mod.id then return rows end end
      local session=Runtime.getSession()
      local pos=#rows+1
      for i,row in ipairs(rows) do if row.id=='save' then pos=i;break end end
      table.insert(rows,pos,{id=mod.id,label=label,onSelect=function()
        if E.active(session) then E.game=game;show(session) end
      end})
      return rows
    end)
  end
  function E.helpLease(wanted)
    local lease
    mod.hooks:wrap('input.step',function(next,game,dt)
      E.game=game
      local Help=require('src.ui.game3.help_system')
      if E.active() and wanted() then
        if not lease then lease={previous=Help.contextOverride} end
        Help.setContext(0)
        if game.input and game.input.setButtonAlias then
          game.input:setButtonAlias('l',nil);game.input:setButtonAlias('r',nil)
        end
      elseif lease then
        if Help.contextOverride==0 then Help.setContext(lease.previous) end
        lease=nil
      end
      return next(game,dt)
    end)
  end
  E.get=function(key) return mod.options:get(key) end
  E.set=function(key,value)
    local game=E.game or Runtime._game
    if not game or not game.mods then return false end
    -- The public options API is read-only; use the native manager write path.
    local result = require('src.mods.ManagerState').new(game):setOption(mod.id,key,value)
    -- setOption returns nil on success in 0.3.39, false only when refused.
    return result ~= false and E.get(key) == value
  end
  return E
end
