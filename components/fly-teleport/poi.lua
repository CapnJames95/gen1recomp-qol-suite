-- Destination maps resolve against the active ROM; arrival tiles are validated at use.
local M={}
local common={
 {'Services','Route117_PokemonDayCare','Route 117 Daycare'},
 {'Services','FallarborTown_MoveRelearnersHouse','Move Reminder'},
 {'Services','LilycoveCity_MoveDeletersHouse','Move Deleter'},
 {'Services','SlateportCity_NameRatersHouse','Name Rater'},
 {'Services','RustboroCity_DevonCorp_2F','Fossil revival'},
 {'Services','MauvilleCity_BikeShop','Bike Shop'},
 {'Activities','Route121_SafariZoneEntrance','Safari entrance'},
 {'Activities','LilycoveCity_ContestLobby','Lilycove contests'},
 {'Activities','BattleFrontier_OutsideWest','Battle Frontier entrance'},
 {'Activities','BattleTower_Outside','Battle Tower entrance'},
 {'Exploration','GraniteCave_1F','Granite Cave'},
 {'Exploration','MeteorFalls_1F_1R','Meteor Falls'},
 {'Exploration','ShoalCave_LowTideEntranceRoom','Shoal Cave (low tide)'},
 {'Exploration','VictoryRoad_1F','Victory Road'},
 {'Exploration','MtPyre_1F','Mt. Pyre'},
 {'Exploration','SkyPillar_1F','Sky Pillar'},
 {'Exploration','SeafloorCavern_Entrance','Seafloor Cavern'},
 {'Collecting','Route123_BerryMastersHouse','Berry Master'},
 {'Collecting','MossdeepCity_StevensHouse','Steven\'s house'},
 {'Training','Route111','Route 111'},
 {'Training','Route119','Route 119'},
}
local kanto={
 {'Services','Route5_PokemonDayCare','Route 5 Daycare'},
 {'Services','FourIsland_PokemonDayCare','Four Island Daycare'},
 {'Services','TwoIsland_House','Move Reminder'},
 {'Services','FuchsiaCity_MoveDeletersHouse','Move Deleter'},
 {'Services','LavenderTown_NameRatersHouse','Name Rater'},
 {'Services','CinnabarIsland_PokemonLab_ExperimentRoom','Fossil lab'},
 {'Activities','FuchsiaCity_SafariZone_Entrance','Safari entrance'},
 {'Activities','CeladonCity_GameCorner','Game Corner'},
 {'Exploration','MtMoon_1F','Mt. Moon'},
 {'Exploration','RockTunnel_1F','Rock Tunnel'},
 {'Exploration','PowerPlant','Power Plant'},
 {'Exploration','SeafoamIslands_1F','Seafoam Islands'},
 {'Exploration','CeruleanCave_1F','Cerulean Cave'},
 {'Exploration','VictoryRoad_1F','Victory Road'},
 {'Collecting','CeladonCity_Condominiums_RoofRoom','Eevee gift'},
 {'Training','Route15','Route 15'},
 {'Training','SevenIsland_SevaultCanyon','Sevault Canyon'},
}
-- Older saves predate our map tracker. Prefer native landmark/world-map flags;
-- use explicit area milestones only where the game has no visit record.
local landmarks={ROUTE117_POKEMON_DAY_CARE='POKEMON_DAYCARE',
 SEAFLOOR_CAVERN_ENTRANCE='SEAFLOOR_CAVERN',SKY_PILLAR_1F='SKY_PILLAR',
 BATTLE_FRONTIER_OUTSIDE_WEST='BATTLE_FRONTIER',BATTLE_TOWER_OUTSIDE='BATTLE_TOWER',
 ROUTE123_BERRY_MASTERS_HOUSE='BERRY_MASTERS_HOUSE'}
local milestones={GRANITE_CAVE_1F='DEWFORD_TOWN',METEOR_FALLS_1F_1R='FALLARBOR_TOWN',
 SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM='MOSSDEEP_CITY',MT_PYRE_1F='LILYCOVE_CITY',
 VICTORY_ROAD_1F='EVER_GRANDE_CITY',ROUTE121_SAFARI_ZONE_ENTRANCE='LILYCOVE_CITY',
 ROUTE111='LAVARIDGE_TOWN',ROUTE119='FORTREE_CITY',ROUTE5_POKEMON_DAY_CARE='CERULEAN_CITY',
 ROUTE15='FUCHSIA_CITY',SEVEN_ISLAND_SEVAULT_CANYON='SEVEN_ISLAND'}
local routeAreas={ [102]='PETALBURG_CITY',[104]='RUSTBORO_CITY',[110]='MAUVILLE_CITY',
 [111]='LAVARIDGE_TOWN',[112]='LAVARIDGE_TOWN',[113]='FALLARBOR_TOWN',
 [114]='FALLARBOR_TOWN',[115]='FALLARBOR_TOWN',[116]='RUSTBORO_CITY',
 [117]='VERDANTURF_TOWN',[118]='FORTREE_CITY',[119]='FORTREE_CITY',
 [120]='LILYCOVE_CITY',[121]='LILYCOVE_CITY',[123]='LILYCOVE_CITY'}
function M.unlocked(s,e,visited,all)
 if all or (visited and visited[e.map]) or s.map==e.map then return true end
 local C=require('src.core.game3.constants').of(s.version)
 local Flags=require('src.core.game3.scripting.flags')
 local Runtime=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space')
 local function has(name)
  local id=C:flag(name)
  return id and (Flags.getFlag(s,nil,id) or
   (Runtime.getSession()==s and Flags.getFlag(Space.store,nil,id))) or false
 end
 local map=e.map:gsub('^[A-Z][A-Z]_','')
 map=map:gsub('^ROUTE_(%d+)','ROUTE%1')
 local kanto=s.version=='firered' or s.version=='leafgreen'
 if kanto and C:flag('FLAG_WORLD_MAP_'..map) then return has('FLAG_WORLD_MAP_'..map) end
 if not kanto and landmarks[map] then return has('FLAG_LANDMARK_'..landmarks[map]) end
 -- City interiors inherit their city's existing visited flag, not a new history.
 local area=map:match('^(.-_CITY)_') or map:match('^(.-_TOWN)_') or map:match('^(.-_ISLAND)_')
 area=area or milestones[map]
 if not kanto and not area then area=routeAreas[tonumber(map:match('^ROUTE(%d+)$'))] end
 if area then return has((kanto and 'FLAG_WORLD_MAP_' or 'FLAG_VISITED_')..area) end
 return false
end
function M.list(s,game,mod)
 local catalog=require('src.import.gba.map_catalog');local out={}
 local rows=(s.version=='firered' or s.version=='leafgreen') and kanto or common
 for _,r in ipairs(rows)do
  local id=catalog.pretToEngine(r[2]);local def=game and game.data and game.data.maps and game.data.maps[id]
  if def then
   local entry={id='poi:'..id,map=id,name=r[3],category=r[1],description=r[1]..': '..r[3]..'. Native interactions and story requirements still apply.'}
   entry.outsideBuilding=r[1]=='Services' or r[3]=='Lilycove contests' or r[3]=='Game Corner' or r[3]=='Eevee gift' or r[3]=='Berry Master' or r[3]=="Steven's house"
   if r[3]=='Safari entrance' then
    entry.entranceTarget=id
    entry.map=catalog.pretToEngine((s.version=='firered' or s.version=='leafgreen') and 'FuchsiaCity' or 'Route121')
    entry.description='Outside Safari reception. Enter the building, speak to the attendant and pay to begin a normal Safari game.'
   end
   out[#out+1]=entry
  end
 end
 local hoenn=mod and mod.find('frlg_qol_hoenn_tools')
 local model=hoenn and hoenn.exports and hoenn.exports.model
 if model and model.berryPatches then
  for _,patch in ipairs(model.berryPatches(s)) do
   local p=patch.location
   out[#out+1]={id='berry:'..patch.id,map=p.map,anchorX=p.x,anchorY=p.y,name=patch.label,category='Collecting',description='Berry patch: land beside the planting spots.'}
  end
 end
 return out
end
return M
