-- Coordinates come from the active edition's native Fly table, never a save patch.
local Catalog = {}
local names = {
  {'PALLET_TOWN', 'Pallet Town'}, {'VIRIDIAN_CITY', 'Viridian City'},
  {'PEWTER_CITY', 'Pewter City'}, {'CERULEAN_CITY', 'Cerulean City'},
  {'LAVENDER_TOWN', 'Lavender Town'}, {'VERMILION_CITY', 'Vermilion City'},
  {'CELADON_CITY', 'Celadon City'}, {'FUCHSIA_CITY', 'Fuchsia City'},
  {'CINNABAR_ISLAND', 'Cinnabar Island'}, {'INDIGO_PLATEAU', 'Indigo Plateau'},
  {'SAFFRON_CITY', 'Saffron City'}, {'ROUTE_4_POKECENTER', 'Route 4 Pokemon Center'},
  {'ROUTE_10_POKECENTER', 'Route 10 Pokemon Center'},
  {'ONE_ISLAND', 'One Island'}, {'TWO_ISLAND', 'Two Island'},
  {'THREE_ISLAND', 'Three Island'}, {'FOUR_ISLAND', 'Four Island'},
  {'FIVE_ISLAND', 'Five Island'}, {'SIX_ISLAND', 'Six Island'}, {'SEVEN_ISLAND', 'Seven Island'},
}
local hoenn = {}
for _, name in ipairs({'LITTLEROOT_TOWN','OLDALE_TOWN','PETALBURG_CITY','RUSTBORO_CITY','DEWFORD_TOWN','SLATEPORT_CITY','MAUVILLE_CITY','VERDANTURF_TOWN','FALLARBOR_TOWN','LAVARIDGE_TOWN','FORTREE_CITY','LILYCOVE_CITY','MOSSDEEP_CITY','SOOTOPOLIS_CITY','PACIFIDLOG_TOWN','EVER_GRANDE_CITY','BATTLE_FRONTIER'}) do
  hoenn[#hoenn+1]={name,name:gsub('_',' ')}
end
local function activeNames()
 return require('src.core.GameVersion').get()=='emerald' and hoenn or names
end
local flagOverrides = {
  INDIGO_PLATEAU='INDIGO_PLATEAU_EXTERIOR',
  ROUTE_4_POKECENTER='ROUTE4_POKEMON_CENTER_1F',
  ROUTE_10_POKECENTER='ROUTE10_POKEMON_CENTER_1F',
}
function Catalog.unlocked(session, section, allUnlocked)
  local key
  for _, entry in ipairs(activeNames()) do
    if section == 'MAPSEC_'..entry[1] then key=entry[1]; break end
  end
  if not key or not session then return false end
  if allUnlocked then return true end
  local Flags=require('src.core.game3.scripting.flags')
  local flag=session.version=='emerald' and (key=='BATTLE_FRONTIER' and 'FLAG_LANDMARK_BATTLE_FRONTIER' or 'FLAG_VISITED_'..key) or 'FLAG_WORLD_MAP_'..(flagOverrides[key] or key)
  -- Flags.getFlag's string aliases are FRLG-only; Emerald must resolve its
  -- own numeric constant before reading either the save or the live store.
  flag=require('src.core.game3.constants').of(session.version):flag(flag)
  if not flag then return false end
  -- Use the same visited flags as the native Fly map, without changing them.
  if Flags.getFlag(session,nil,flag) then return true end
  local Runtime=require('src.core.game3.runtime')
  local Space=require('src.core.game3.scripting.space')
  return Runtime.getSession()==session and Flags.getFlag(Space.store,nil,flag) or false
end
function Catalog.list()
  local rows = {}
  for _, entry in ipairs(activeNames()) do
    rows[#rows + 1] = {section='MAPSEC_'..entry[1], name=entry[2]}
  end
  return rows
end
function Catalog.destination(section)
  local known = false
  for _, entry in ipairs(activeNames()) do if section == 'MAPSEC_'..entry[1] then known = true; break end end
  if not known then return nil, 'Unknown Fly destination.' end
  local ok,dest
  if require('src.core.GameVersion').get()=='emerald' then
    local session=require('src.core.game3.runtime').getSession()
    local C=require('src.core.game3.constants').of('emerald')
    local sec=C:require('region_map_sections',section)
    local R=require('src.ui.game3.rse.region_map')
    ok,dest=pcall(function()
      local special=R.flyWarpDestination(session,sec,0)
      if special then return special end
      local row=R.flyHealLocation({session=session},sec,0)
      return row and require('src.core.game3.heal_locations').get(row.healLocation)
    end)
  else
    ok,dest=pcall(require('src.core.game3.field').flyDestination,section)
  end
  if not ok or not dest then return nil, 'Native Fly destination data is unavailable: '..tostring(dest) end
  return {map=dest.map, x=dest.x, y=dest.y, facing='down'}
end
return Catalog
