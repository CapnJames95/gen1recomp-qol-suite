-- An exchange is not a new acquisition. Keep the marker synchronous and
-- restore it even if another inventory hook throws.
local function addExchangedBike(B, bag, id)
 local previous=B._modBikeExchange
 B._modBikeExchange=bag
 local ok,result=pcall(B.add,bag,id,1)
 B._modBikeExchange=previous
 if not ok then error(result)end
 return result
end
-- Read models are built on demand, never in the frame loop. No RNG is consumed.
local M={}
local function req(n) return require('src.core.game3.'..n) end
local function copy(t) local o={};for k,v in pairs(t or {})do o[k]=type(v)=='table' and copy(v) or v end;return o end
M.copy=copy
local function pretty(s) return tostring(s or 'Unknown'):gsub('^[A-Z][A-Z]_',''):gsub('_',' ') end
local function session()return req('runtime').getSession()end
local function c()return req('constants').active(session())end
local function var(name,s)return req('scripting.flags').getVar({vars=s.vars,flags=s.flags},nil,c():require('vars',name))end
local function flag(name,s)return req('scripting.flags').getFlag({vars=s.vars,flags=s.flags},nil,c():require('flags',name))end
function M.ready(s)
 local rt=req('runtime');local game=M.game or rt._game;local p=req('player');local sp=req('scripting.space')
 if not s or s~=session() or req('profile').forSession(s).family~='rse' or not game or game.phase~='field' then return false,'Reopen Hoenn Tools in a Hoenn field save.' end
 if req('battle').isActive() or req('battle_transition').isActive() or req('field').locked or p.moving or req('warp').isBusy() or require('src.ui.game3.fade').isActive()
   or (sp.vm and sp.vm:isRunning()) or (sp._immediateVm and sp._immediateVm:isRunning()) then return false,'Finish movement, dialogue or battle first.' end
 if ((s.version=='ruby' or s.version=='sapphire') and tostring(req('map').current):find('BATTLE_TOWER',1,true)) or (s.frontier and (s.frontier.challengeStatus or 0)~=0) or req('safari').isActive(s) or (game.speedLocked and game:speedLocked()) then return false,'Finish the challenge or linked activity first.' end
 return true
end
local function events()return req('scripting.space').bundle.events end
local function locations()
 local berries,bases={},{}
 for map,e in pairs(events() or {})do
  for _,o in ipairs(e.objects or {})do
   if o.berryTreeId and o.movementType==c():require('movement','MOVEMENT_TYPE_BERRY_TREE_GROWTH') then berries[o.berryTreeId]={map=map,x=o.x,y=o.y} end
  end
  for _,o in ipairs(e.bgEvents or {})do if o.secretBaseId then bases[o.secretBaseId]={map=map,x=o.x,y=o.y}end end
 end
 return berries,bases
end
function M.rematches(s)
 local rs=s.version=='ruby' or s.version=='sapphire'
 local R=req(rs and 'rs.rematch' or 'rse.rematch');local pack=req('scripting.trainers').pack();local rows={}
 local groups=c():raw('map_groups').byName
 for i=0,(rs and R.COUNT or R.count())-1 do
  local e=rs and R.table()[i] or R.entry(i);local id=e.trainers[1]
  -- Native readiness includes the separate Gym Leader path.
  if id and (rs or not R.isForbidden(s,i)) and R.isTrainerReadyForRematch(s,id) then
   local map='Unknown location';for name,g in pairs(groups)do if g.group==e.mapGroup and g.num==e.mapNum then map=pretty(name:gsub('^MAP_',''));break end end
   rows[#rows+1]={name=(pack.trainers[id] or {}).name or ('Trainer '..id),location=map,gym=not rs and i>R.SPECIAL_TRAINER_START and i<R.ELITE_FOUR_ENTRIES}
  end
 end
 return rows
end
function M.berries(s)
 local B=req('rse.berry_trees');local loc=locations();local rows={}
 for id=1,B.COUNT do
  local t=(s.berryTrees or {})[id]
  if t and (t.berry or 0)>0 and (t.stage or 0)>0 then
   rows[#rows+1]={id=id,name=B.name(t.berry),stage=t.stage,watered=t['watered'..t.stage]==true,
    minutes=t.minutesUntilNextStage or 0,yield=t.berryYield or 0,paused=t.stopGrowth==true,location=loc[id]}
  end
 end
 table.sort(rows,function(a,b)if (a.stage==5)~=(b.stage==5)then return a.stage==5 end;return a.id<b.id end)
 return rows
end
-- All imported planting sites, including empty or not-yet-seen trees.
-- Connected neighboring trees share one destination; distant patches on the
-- same route remain separate.
function M.berryPatches(s)
 local loc=locations();local ids={};local seen={};local patches={}
 for id in pairs(loc)do ids[#ids+1]=id end;table.sort(ids)
 local growing={};for _,tree in ipairs(M.berries(s))do growing[tree.id]=tree end
 for _,id in ipairs(ids)do if not seen[id]then
  local patch={id=id,location=loc[id],trees={}};local queue={id};seen[id]=true
  local index=1
  while index<=#queue do
   local current=queue[index];index=index+1
   patch.trees[#patch.trees+1]=growing[current] or {id=current,name='Empty soil',stage=0,location=loc[current]}
   for _,other in ipairs(ids)do
    if not seen[other] and loc[current].map==loc[other].map
      and math.abs(loc[current].x-loc[other].x)+math.abs(loc[current].y-loc[other].y)<=2 then
     seen[other]=true;queue[#queue+1]=other
    end
   end
  end
  table.sort(patch.trees,function(a,b)return a.id<b.id end)
  patches[#patches+1]=patch
 end end
 table.sort(patches,function(a,b)
  if a.location.map~=b.location.map then return a.location.map<b.location.map end
  if a.location.y~=b.location.y then return a.location.y<b.location.y end
  return a.location.x<b.location.x
 end)
 local counts={};for _,p in ipairs(patches)do counts[p.location.map]=(counts[p.location.map]or 0)+1 end
 local ordinal={};for _,p in ipairs(patches)do
  local map=p.location.map;ordinal[map]=(ordinal[map]or 0)+1
  p.label=(map:match('_ROUTE130$') and 'Mirage Island (Route 130)' or pretty(map))..(counts[map]>1 and (' - patch '..ordinal[map]) or '')
 end
 return patches
end
-- Resolve live tree data and choose an adjacent walkable tile, never the tree itself.
local function teleportBerry(s,id,emptyAllowed)
 local ok,why=M.ready(s);if not ok then return false,why end
 local loc=locations();local e=loc[id];local tree=(s.berryTrees or {})[id]
 if not e or (not emptyAllowed and (not tree or (tree.berry or 0)==0 or (tree.stage or 0)==0)) then return false,'This berry tree is no longer available.'end
 local game=M.game or req('runtime')._game;local Map=req('map');local Coll=req('collision');local P=require('src.core.CollPermissions')
 local def=game.data and game.data.maps and game.data.maps[e.map]
 local layout=def and Map.ensureMidLayout(game,e.map,def);local ev=events()[e.map]
 if not layout or not ev then return false,'Berry destination is unavailable.'end
 local function clear(x,y)
  if x<0 or y<0 or x>=layout.width or y>=layout.height then return false end
  local c=layout:collAt(x,y)
  if not P.isWalkable(c) or P.isLedge(c) or Coll.isWarpMetatileBehavior(Coll.behaviorOn(def,x,y)) then return false end
  for _,w in ipairs(def.warps or {})do if w.x==x and w.y==y then return false end end
  for _,o in ipairs(ev.objects or {})do if o.x==x and o.y==y then return false end end
  for _,o in ipairs(ev.coordEvents or {})do if o.x==x and o.y==y then return false end end
  return true
 end
 for _,p in ipairs({{e.x,e.y+1,'up'},{e.x,e.y-1,'down'},{e.x+1,e.y,'left'},{e.x-1,e.y,'right'}})do
  if clear(p[1],p[2])then
   local success,result,err=pcall(req('warp').request,nil,game,e.map,p[1],p[2],p[3],{fade=false,se=false})
   if not success or not result then return false,'Teleport failed: '..tostring(err or result)end
   local player=req('player');player.surfing=false;player.underwater=false;player.biking=false;player.bikeType=nil
   player.facing=p[3];player.syncSavePosition(game);return true
  end
 end
 return false,'No safe landing tile beside this berry tree.'
end
function M.teleportBerry(s,id)return teleportBerry(s,id,false)end
function M.teleportBerryPatch(s,id)
 for _,patch in ipairs(M.berryPatches(s))do if patch.id==id then
  local reason
  for _,tree in ipairs(patch.trees)do
   local ok,why=teleportBerry(s,tree.id,true)
   if ok then return true end
   reason=why
   if why~='No safe landing tile beside this berry tree.'then return false,why end
  end
  return false,reason
 end end
 return false,'This berry patch is unavailable.'
end
function M.bikeName(s)
 local B=req('bag');local P=req('player');local mach,acro=c():require('items','ITEM_MACH_BIKE'),c():require('items','ITEM_ACRO_BIKE')
 if B.has(s.bag,mach,1) and B.has(s.bag,acro,1)then
  if P.biking then return P.bikeType=='acro' and 'Acro' or 'Mach'end
  return (s.modData and s.modData.hoenn_tools and s.modData.hoenn_tools.bikeChoice) or (s.registeredItem==acro and 'Acro' or 'Mach')
 end
 if B.has(s.bag,mach,1)then return 'Mach'end
 if B.has(s.bag,acro,1)then return 'Acro'end
 return 'None'
end
M.facilities={
 {name='Tower',key='tower',grid=true,modes=4,rule='Choose 3 for Singles, 4 for Doubles or 2 for Multi.'},
 {name='Dome',key='dome',grid=true,modes=2,rule='Enter 3, then select 2 for each tournament battle.'},
 {name='Palace',key='palace',grid=true,modes=2,rule='Enter 3. Nature influences automatic move choices.'},
 {name='Arena',key='arena',rule='Enter 3. No switching; three-turn judging.'},
 {name='Factory',key='factory',grid=true,modes=2,rule='Use rental Pokemon; your party is not entered.'},
 {name='Pike',key='pike',rule='Enter 3. Choose paths through random room challenges.'},
 {name='Pyramid',key='pyramid',rule='Enter 3 without held items. Uses the Battle Bag.'},
}
function M.frontier(s,index)
 local U=req('rse.frontier.util');local d=M.facilities[index];local f=s.frontier or {};local rows={}
 local suffix=d.key=='arena' or d.key=='pike' or d.key=='pyramid'
 local current=f[d.key..'WinStreaks'] or {};local record=f[d.key..(suffix and 'RecordStreaks' or 'RecordWinStreaks')] or {}
 for mode=0,(d.modes or 1)-1 do for level=0,1 do
  rows[#rows+1]={mode=mode,level=level,current=d.grid and U.get2(current,mode,level) or U.get1(current,level),record=d.grid and U.get2(record,mode,level) or U.get1(record,level)}
 end end
 return {name=d.name,rule=d.rule,symbols=U.symbolCount(s,index-1),bp=f.battlePoints or 0,rows=rows,active=(f.challengeStatus or 0)~=0}
end
-- Read saved records without native state() normalizing or creating save fields.
function M.tower(s)
 local b=s.battleTower or {};local rows={}
 for i=1,2 do
  rows[#rows+1]={level=i==1 and 50 or 100,current=(b.currentWinStreaks or {})[i] or 0,
   record=(b.recordWinStreaks or {})[i] or 0}
 end
 return rows
end
function M.eligibility(s,index,level,slots)
 if s.version=='ruby' or s.version=='sapphire' then
  local code=req('rse.battle_tower_rs').validateParty(s,slots,level)
  return {({[17]='Select three different eligible party slots: no eggs, banned species or Pokemon above the level limit.',
   [18]='Selected trio contains duplicate species.',[19]='Selected trio contains duplicate held items.'})[code]
   or 'Selected trio passes native Battle Tower entry rules.'}
 end
 local U=req('rse.frontier.util');local P=req('pokemon');local names,items={},{};local issues={}
 if index==5 then return {'Factory uses rentals.'} end
 for _,slot in ipairs(slots or {})do
  local m=s.party[slot]
  if not m then issues[#issues+1]='Missing party slot '..slot
  else
   local name=m.nickname or P.name(m.species)
   if P.isEgg(m) or U.isBanned(m.species) then issues[#issues+1]=name..': egg or banned species' end
   if level==0 and (tonumber(m.level) or 0)>50 then issues[#issues+1]=name..': above level 50' end
   if names[m.species] then issues[#issues+1]=name..': duplicate species' end;names[m.species]=true
   local item=m.heldItem or m.item or 0
   if index==7 and item~=0 then issues[#issues+1]=name..': remove held item'
   elseif item~=0 and items[item]then issues[#issues+1]=name..': duplicate held item' end
   if item~=0 then items[item]=true end
  end
 end
 if #issues==0 then issues[1]='Selected trio passes basic entry rules.' end
 return issues
end
function M.preview(mon,block)
 local P=req('rse.pokeblock');local clone=copy(mon);local before=copy(clone.contest or {})
 local changed=P.feed(copy(block),clone)
 return {before=before,after=clone.contest or {},allowed=(before.sheen or 0)<255,favorite=P.favoriteName(req('pokemon').natureId(mon.personality))}
end
function M.contestMoves(mon)
 local C=req('rse.contest');local data=C.data();local out={};local moves=req('pokemon')
 for _,id in ipairs(mon.moves or {})do
  local row=data.moves[id];local effect=row and data.effects[row.effect]
  if effect then
   local combos={}
   for _,nextId in ipairs(mon.moves or {})do
    if C.areMovesCombo({data=data},id,nextId)>0 then combos[#combos+1]=moves.moveName(nextId)end
   end
   out[#out+1]={name=moves.moveName(id),category=C.CATEGORY_NAMES[row.category],appeal=effect.appeal,jam=effect.jam,description=effect.description,combos=combos}
  end
 end
 return out
end
function M.daily(s)
 local F=req('scripting.natives_field_rse');local time=req('rtc').calcLocalTime(s);local hour=(time.hours or 0)%24
 local high=F.SHOAL_TIDE[hour]==1;local nextHours=1
 while nextHours<24 and (F.SHOAL_TIDE[(hour+nextHours)%24]==1)==high do nextHours=nextHours+1 end
 local emerald=s.version=='emerald'
 local location=emerald and var('VAR_ABNORMAL_WEATHER_LOCATION',s) or 0
 local routes={114,114,115,115,116,116,118,118,105,105,125,125,127,127,129,129}
 return {time=time,high=high,nextHours=nextHours,mirage=F.isMirageIslandPresent(s),
  weather=emerald and (routes[location] and ((location>=9 and 'Marine Cave: Route ' or 'Terra Cave: Route ')..routes[location]) or 'No active weather cave') or nil,
  ending=emerald and var('VAR_SHOULD_END_ABNORMAL_WEATHER',s)~=0}
end
function M.bases(s)
 local _,loc=locations();local out={}
 for i,b in ipairs(s.secretBases or {})do
  if (b.secretBaseId or 0)~=0 then out[#out+1]={index=i-1,name=i==1 and 'Your base' or b.trainerName,
   location=loc[b.secretBaseId],registered=(b.registryStatus or 0)~=0,battled=(b.battledOwnerToday or 0)~=0,decorations=copy(b.decorations or {})}end
 end
 return out
end
function M.decorations(s)
 local D=req('rse.decoration_inventory');local rows={}
 for _,list in pairs(s.decorationInventory or {})do for _,id in ipairs(list)do
  if id~=0 then local def=D.info(id);rows[#rows+1]={id=id,name=def and def.name or tostring(id)}end
 end end
 table.sort(rows,function(a,b)return a.name<b.name end);return rows
end
function M.swapBike(s)
 local ok,why=M.ready(s);if not ok then return false,why end
 local B=req('bag');local P=req('player');local R=req('bike.rse');local U=req('item_use')
 if P.surfing or P.underwater or R.onRail() or not R.notUsingAcroOnBumpySlope() or flag('FLAG_SYS_CYCLING_ROAD',s)then return false,'Step onto ordinary ground off Cycling Road first.'end
 local mach,acro=c():require('items','ITEM_MACH_BIKE'),c():require('items','ITEM_ACRO_BIKE')
 local hasM,hasA=B.has(s.bag,mach,1),B.has(s.bag,acro,1)
 if not hasM and not hasA then return false,'Obtain a bike from Rydel first.'end
 local from=(hasM and hasA) and (M.bikeName(s)=='Acro' and acro or mach) or (hasM and mach or acro)
 local to=from==mach and acro or mach
 -- Validate native riding constraints before any inventory edit.
 local riding=P.biking
 if riding then local success=U.useBike(s,from);if not success then return false,'Cannot switch bikes here.'end end
 if not (hasM and hasA) then
  assert(B.remove(s.bag,from,1))
  if not addExchangedBike(B,s.bag,to)then assert(addExchangedBike(B,s.bag,from));if riding then U.useBike(s,from)end;return false,'No room for the replacement bike.'end
 end
 if s.registeredItem==from then s.registeredItem=to end
 s.modData=s.modData or {};s.modData.hoenn_tools=s.modData.hoenn_tools or {};s.modData.hoenn_tools.bikeChoice=to==mach and 'Mach' or 'Acro'
 if riding then U.useBike(s,to)end
 return true,to==mach and 'Mach Bike selected.' or 'Acro Bike selected.'
end
-- Exactly the native Feebas spot sequence, using a private seed. No encounter roll.
function M.feebasSpots(seed)
 local spots={};local n=0
 while n<6 do seed=(req('rng').mulU32(1103515245,seed)+12345)%4294967296;local id=math.floor(seed/65536)%447;if id==0 then id=447 end
  if id>=4 then n=n+1;spots[id]=true end
 end
 return spots
end
function M.feebas(s,reveal)
 local Map=req('map');local P=req('player');local Coll=req('collision')
 if Map.current~=req('profile').forSession(s).map.enginePrefix..'ROUTE119' then return {message='Visit Route 119 and face a fishing tile.'}end
 local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}};local d=delta[P.facing] or delta.down
 local x,y=P.cellX+d[1],P.cellY+d[2];local extra=req('encounters').loadCacheFile('wild_extra.lua')
 local sections=extra.feebas.sections;local section
 for _,sec in ipairs(sections)do if y>=sec.yMin and y<=sec.yMax then section=sec end end
 local layout=Coll._mapDef and Coll._mapDef.midLayout;local bits=req('scripting.collision_rse')._tileBits or {}
 local waterfall=req('mb').id('WATERFALL');local id
 local function fishable(tx,ty)local b=Coll.behavior(tx,ty);return b~=waterfall and math.floor((bits[b] or 0)/2)%2==1 end
 if section and layout and fishable(x,y)then
  local n=section.spotBase
  for ty=section.yMin,section.yMax do for tx=0,layout.width-1 do
   if fishable(tx,ty)then n=n+1;if tx==x and ty==y then id=n end end
  end end
 end
 local seed=tonumber(s.dewfordTrends and s.dewfordTrends[1] and s.dewfordTrends[1].rand) or 0
 local notes=s.modData and s.modData.hoenn_tools;notes=notes and notes.feebas
 return {x=x,y=y,id=id,seed=seed,valid=reveal and id and M.feebasSpots(seed)[id] or false,
  marked=id and notes and notes.seed==seed and notes.tiles[tostring(id)]==true or false}
end
function M.markFeebas(s)
 local ok,why=M.ready(s);if not ok then return false,why end
 local spot=M.feebas(s,false);if not spot.id then return false,'Face a fishing tile on Route 119 first.'end
 s.modData=s.modData or {};s.modData.hoenn_tools=s.modData.hoenn_tools or {};local h=s.modData.hoenn_tools
 if not h.feebas or h.feebas.seed~=spot.seed then h.feebas={seed=spot.seed,tiles={}}end
 h.feebas.tiles[tostring(spot.id)]=not spot.marked
 return true,spot.marked and 'Tile mark removed.' or 'Tile marked as searched. This does not rule out Feebas.'
end
function M.openDecorations(s)
 local ok,why=M.ready(s);if not ok then return false,why end
 local SB=req('rse.secret_base')
 if not SB.curMapIsSecretBase(s) or SB.ownedByAnotherPlayer(s) then return false,'Enter your own secret base first.'end
 -- The native close handler runs the base-PC shutdown script at the facing tile.
 local P=req('player');local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}};local d=delta[P.facing] or delta.down
 local grid=SB.fieldGrid();local pc=grid.metatileId('METATILE_SecretBase_PC')
 if not pc or grid.metatile(P.cellX+d[1],P.cellY+d[2])~=pc then return false,'Face your base PC to arrange decorations safely.'end
 require('src.ui.game3.rse.decoration').open({session=s})
 return true
end
function M.registry(s)
 local rows={}
 for index=2,req('rse.secret_base').COUNT do local b=(s.secretBases or {})[index]
  if b and (b.secretBaseId or 0)~=0 and (b.registryStatus or 0)~=0 then rows[#rows+1]={id=index-1,name=(b.trainerName or 'Unknown').."'s base"}end
 end
 return rows
end
function M.unregister(s,id,expected)
 local ok,why=M.ready(s);if not ok then return false,why end
 local SB=req('rse.secret_base')
 if not id or id<1 or id>=SB.COUNT or (s.secretBases or {})[id+1]~=expected or not SB.isRegistered(id,s)then return false,'Registry changed. Reopen the list.'end
 SB.unregister(id,s)
 return true,'Base removed from the registry.'
end
M.pretty=pretty
return M
