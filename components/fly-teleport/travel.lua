return function(mod)
  local E={}
  local Runtime=require('src.core.game3.runtime')
  local Map=require('src.core.game3.map')
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
    if not s or (s.version~='firered' and s.version~='leafgreen' and s.version~='emerald' and s.version~='ruby' and s.version~='sapphire') or not E.game or E.game.phase~='field' then return false,'Load a Gen 3 field save.' end
    if Battle.isActive() or require('src.core.game3.battle_transition').isActive() or Field.locked or Player.moving or Warp.isBusy() or Fade.isActive()
      or (Space.vm and Space.vm:isRunning()) or (Space._immediateVm and Space._immediateVm:isRunning()) then
      return false,'Finish the battle, dialogue or movement first.'
    end
    if (s.version=='ruby' or s.version=='sapphire') and tostring(Map.current):find('BATTLE_TOWER',1,true) then return false,'Leave the Battle Tower before using this tool.' end
    if s.version=='emerald' and s.frontier and (s.frontier.challengeStatus or 0)~=0 then return false,'Finish the Battle Frontier challenge first.' end
    if E.game.speedLocked and E.game:speedLocked() then return false,'Finish the linked activity first.' end
    if require('src.core.game3.safari').isActive(s) then return false,'Leave the Safari game before teleporting.' end
    return true
  end
  function E.restricted(id)
    id=tostring(id):upper()
    -- Never land behind Safari admission, including old saved/recent points.
    if id:find('SAFARI',1,true) then return true end
    for _,word in ipairs({'SAFARI','BATTLE_TOWER','BATTLE_FRONTIER','BATTLE_PYRAMID','BATTLE_PIKE','BATTLE_DOME','BATTLE_PALACE','BATTLE_ARENA','BATTLE_FACTORY','UNION_ROOM','TRADE_CENTER','COLOSSEUM','RECORD_CORNER','SECRET_BASE','HALL_OF_FAME','INSIDE_OF_TRUCK','CABLE_CAR','ELEVATOR'}) do
      if id:find(word,1,true) then
        if id:find('ENTRANCE',1,true) or id:find('OUTSIDE',1,true) then return false end
        return true
      end
    end
    return false
  end
  function E.position()
    local ok,why=E.ready();if not ok then return nil,why end
    local s=E.session();local id=Map.current or s.map
    if E.restricted(id) then return nil,'This activity or temporary map cannot be saved or used as a return point.' end
    return {map=id,x=Player.cellX,y=Player.cellY,facing=Player.facing or 'down',surfing=Player.surfing==true,underwater=Player.underwater==true,version=s.version,name='Previous location'}
  end
  function E.destination(e)
    local id=e.map
    if e.version and e.version~=E.session().version then return nil,'This location belongs to another game.' end
    if E.restricted(id) then return nil,'Restricted activity destination.' end
    if type(e.x)~='number' or type(e.y)~='number' or e.x%1~=0 or e.y%1~=0 then return nil,'Invalid destination coordinates.' end
    local def=E.game and E.game.data and E.game.data.maps and E.game.data.maps[id]
    local layout=def and Map.ensureMidLayout(E.game,id,def)
    if not layout then return nil,'This map is missing from the loaded game.' end
    local ev=Space.bundle and Space.bundle.events and Space.bundle.events[id]
    if not ev then return nil,'Destination scripts are unavailable.' end
    local function clear(x,y)
      if x<0 or y<0 or x>=layout.width or y>=layout.height then return false end
      local c=layout:collAt(x,y)
      local water=Collision.isWaterOn(def,x,y,c)
      if (water and not e.surfing and not e.underwater) or (not water and e.surfing) then return false end
      if (not P.isWalkable(c) and not (water and (e.surfing or e.underwater))) or P.isLedge(c) or Collision.isWarpMetatileBehavior(Collision.behaviorOn(def,x,y)) then return false end
      if Map.current==id then
        local Objects=require('src.core.game3.objects')
        if Objects.hasMap() and Objects.blocks(x,y,nil,layout.elevAt and layout:elevAt(x,y)) then return false end
      end
      for _,w in ipairs(def.warps or {}) do if w.x==x and w.y==y then return false end end
      for _,o in ipairs(ev.objects or {}) do if o.x==x and o.y==y then return false end end
      for _,o in ipairs(ev.coordEvents or {}) do if o.x==x and o.y==y then return false end end
      return true
    end
    if e.surfing or e.underwater then
      local move=e.underwater and 'DIVE' or 'SURF'
      local Moves=require('src.core.game3.field_moves');local Bag=require('src.core.game3.bag');local C=require('src.core.game3.constants').of(E.session().version)
      local item=C:id('items',e.underwater and 'ITEM_HM08' or 'ITEM_HM03')
      if not item or not Bag.has(E.session().bag,item,1) or not Moves.hasBadge(Space.store or E.session(),move) then return nil,'Requires '..move..' HM and its badge.' end
    end
    if clear(e.x,e.y) then return {map=id,x=e.x,y=e.y,facing=e.facing or 'down',surfing=e.surfing,underwater=e.underwater,version=E.session().version,name=e.name,id=e.id} end
    return nil,'The landing tile is blocked or its terrain has changed.'
  end
  -- Follow native exits through a building's floors to its outdoor door.
  -- This also handles POIs on upper floors without guessing coordinates.
  function E.buildingEntrance(id)
    local maps=E.game.data.maps;local Dataset=require('src.core.game3.dataset')
    local queue,seen={id},{[id]=true};local index=1
    while queue[index] do
      local current=queue[index];index=index+1
      local def=maps[current]
      for _,w in ipairs(def and def.warps or {})do
        local target=Collision.resolveWarpDestination(E.game,w)
        local outside=target and maps[target]
        if outside and Dataset.isOutdoorMapType(outside.mapType) then
          -- Require the matching outdoor door; never pick another building.
          for _,door in ipairs(outside.warps or {})do
            if Collision.resolveWarpDestination(E.game,door)==current then
              return target,current,door.x,door.y
            end
          end
        elseif outside and not seen[target] and Dataset.isIndoorMapType(outside.mapType) then
          seen[target]=true;queue[#queue+1]=target
        end
      end
    end
    return nil
  end
  function E.poi(entry)
    if entry.outsideBuilding then
      local map,target=E.buildingEntrance(entry.map)
      if not map then return nil,'No safe outdoor building entrance is available.' end
      return E.poi({map=map,entranceTarget=target,name=entry.name,id=entry.id})
    end
    local def=E.game.data.maps[entry.map]
    if not def then return nil,'Map unavailable.' end
    Map.ensureMidLayout(E.game,entry.map,def)
    local anchors=entry.anchorX and {{x=entry.anchorX,y=entry.anchorY}} or def.warps or {}
    for _,w in ipairs(anchors) do
      local target=entry.entranceTarget and Collision.resolveWarpDestination(E.game,w)
      if not entry.entranceTarget or target==entry.entranceTarget then
      for distance=1,4 do
        for _,d in ipairs({{0,1,'up'},{0,-1,'down'},{1,0,'left'},{-1,0,'right'}}) do
          local p=E.destination({map=entry.map,x=w.x+d[1]*distance,y=w.y+d[2]*distance,facing=d[3],name=entry.name,id=entry.id})
          if p then return p end
        end
      end
      end
    end
    return nil,'No safe entrance landing point is available.'
  end
  function E.warp(p)
    local ready,why=E.ready();if not ready then return false,why end
    local checked;checked,why=E.destination(p);if not checked then return false,why end
    local ok,result,err=pcall(Warp.request,nil,E.game,p.map,p.x,p.y,p.facing,{fade=false,se=false})
    if not ok or not result then return false,'Teleport failed: '..tostring(err or result) end
    -- Land on foot; native map entry handles scripts and map state.
    Player.surfing=p.surfing==true;Player.biking=false;Player.underwater=p.underwater==true;Player.bikeType=nil
    Player.facing=p.facing;Player.syncSavePosition(E.game)
    return true
  end
  return E
end
