return function(mod)
  local E={}
  local Runtime=require('src.core.game3.runtime')
  local Map=require('src.core.game3.map')
  local Catalog=require('src.import.gba.map_catalog')
  local Space=require('src.core.game3.scripting.space')
  local Player=require('src.core.game3.player')
  local Warp=require('src.core.game3.warp')
  local Field=require('src.core.game3.field')
  local Battle=require('src.core.game3.battle')
  local Fade=require('src.ui.game3.fade')
  local P=require('src.core.CollPermissions')
  local Collision=require('src.core.game3.collision')
  E.session=Runtime.getSession
  function E.ready()
    local s=E.session()
    if not s or (s.version~='firered' and s.version~='leafgreen' and s.version~='emerald') or not E.game or E.game.phase~='field' then return false,'Load a FireRed, LeafGreen or Emerald field save.' end
    if Battle.isActive() or require('src.core.game3.battle_transition').isActive() or Field.locked or Player.moving or Warp.isBusy() or Fade.isActive()
      or (Space.vm and Space.vm:isRunning()) or (Space._immediateVm and Space._immediateVm:isRunning()) then
      return false,'Finish the battle, dialogue or movement first.'
    end
    if s.version=='emerald' and s.frontier and (s.frontier.challengeStatus or 0)~=0 then return false,'Finish the Battle Frontier challenge first.' end
    if E.game.speedLocked and E.game:speedLocked() then return false,'Finish the linked activity first.' end
    if require('src.core.game3.safari').isActive(s) then return false,'Leave the Safari game before teleporting.' end
    return true
  end
  function E.destination(e)
    local id=e.map:match('^EM_') and e.map or Catalog.pretToEngine(e.map)
    local def=E.game and E.game.data and E.game.data.maps and E.game.data.maps[id]
    local layout=def and Map.ensureMidLayout(E.game,id,def)
    if not layout then return nil,'This map is missing from the loaded game.' end
    local ev=Space.bundle and Space.bundle.events and Space.bundle.events[id]
    if not ev then return nil,'Day Care scripts are unavailable.' end
    local function clear(x,y)
      if x<0 or y<0 or x>=layout.width or y>=layout.height then return false end
      local c=layout:collAt(x,y)
      if not P.isWalkable(c) or P.isLedge(c) or Collision.isWarpMetatileBehavior(Collision.behaviorOn(def,x,y)) then return false end
      for _,w in ipairs(def.warps or {}) do if w.x==x and w.y==y then return false end end
      for _,o in ipairs(ev.objects or {}) do if o.x==x and o.y==y then return false end end
      for _,o in ipairs(ev.coordEvents or {}) do if o.x==x and o.y==y then return false end end
      return true
    end
    if clear(e.x,e.y) then return {map=id,x=e.x,y=e.y,facing=e.facing} end
    return nil,'No safe landing tile at this Day Care.'
  end
  function E.warp(p)
    local ready,why=E.ready();if not ready then return false,why end
    local ok,result,err=pcall(Warp.request,nil,E.game,p.map,p.x,p.y,p.facing,{fade=false,se=false})
    if not ok or not result then return false,'Teleport failed: '..tostring(err or result) end
    -- Both destinations are indoors. Native map entry handles scripts.
    Player.surfing=false;Player.biking=false;Player.underwater=false;Player.bikeType=nil
    Player.facing=p.facing;Player.syncSavePosition(E.game)
    return true
  end
  return E
end
