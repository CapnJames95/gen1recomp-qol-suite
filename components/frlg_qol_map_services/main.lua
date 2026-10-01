return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Map = require("src.ui.game3.region_map")
  local services = {
    MAPSEC_PALLET_TOWN = { "Oak's Lab", "Home: healing" },
    MAPSEC_VIRIDIAN_CITY = { "Pokemon Center / Mart", "Gym: story-dependent access" },
    MAPSEC_PEWTER_CITY = { "Pokemon Center / Mart", "Museum / Gym" },
    MAPSEC_CERULEAN_CITY = { "Pokemon Center / Mart", "Bike Shop / Gym" },
    MAPSEC_VERMILION_CITY = { "Pokemon Center / Mart", "Fan Club / Fishing Guru / Gym" },
    MAPSEC_LAVENDER_TOWN = { "Pokemon Center / Mart", "Name Rater / Pokemon Tower" },
    MAPSEC_CELADON_CITY = { "Pokemon Center", "Department Store / Game Corner", "Gym" },
    MAPSEC_FUCHSIA_CITY = { "Pokemon Center / Mart", "Safari Zone / Fishing Guru / Gym" },
    MAPSEC_SAFFRON_CITY = { "Pokemon Center / Mart", "Silph Co. / Fighting Dojo / Gym" },
    MAPSEC_CINNABAR_ISLAND = { "Pokemon Center / Mart", "Fossil Lab / Gym" },
    MAPSEC_INDIGO_PLATEAU = { "Pokemon Center / shop", "Pokemon League" },
    MAPSEC_ONE_ISLAND = { "Pokemon Center / Celio" },
    MAPSEC_TWO_ISLAND = { "Pokemon Center / market stall", "Move Reminder: mushrooms" },
    MAPSEC_THREE_ISLAND = { "Pokemon Center / Mart" },
    MAPSEC_FOUR_ISLAND = { "Pokemon Center / Mart", "Day Care" },
    MAPSEC_FIVE_ISLAND = { "Pokemon Center" },
    MAPSEC_SIX_ISLAND = { "Pokemon Center / Mart" },
    MAPSEC_SEVEN_ISLAND = { "Pokemon Center / Mart" },
  }
  if require("src.core.GameVersion").get()=="emerald" then
    services={
      MAPSEC_LITTLEROOT_TOWN={"Birch's Lab / Home healing"},
      MAPSEC_OLDALE_TOWN={"Pokemon Center / Mart"},
      MAPSEC_PETALBURG_CITY={"Pokemon Center / Mart / Gym"},
      MAPSEC_RUSTBORO_CITY={"Pokemon Center / Mart / Gym", "Devon fossil revival / Cut"},
      MAPSEC_DEWFORD_TOWN={"Pokemon Center / Gym / Fishing Guru"},
      MAPSEC_SLATEPORT_CITY={"Pokemon Center / Mart / Market", "Name Rater / Harbor"},
      MAPSEC_MAUVILLE_CITY={"Pokemon Center / Mart / Gym", "Bike Shop / Game Corner"},
      MAPSEC_VERDANTURF_TOWN={"Pokemon Center / Mart / Battle Tent"},
      MAPSEC_FALLARBOR_TOWN={"Pokemon Center / Mart / Battle Tent", "Move Reminder: Heart Scale"},
      MAPSEC_LAVARIDGE_TOWN={"Pokemon Center / Mart / Gym", "Hot springs / Egg gift"},
      MAPSEC_FORTREE_CITY={"Pokemon Center / Mart / Gym"},
      MAPSEC_LILYCOVE_CITY={"Pokemon Center / Department Store", "Move Deleter / Contest Hall / Harbor"},
      MAPSEC_MOSSDEEP_CITY={"Pokemon Center / Mart / Gym", "Space Center / Steven's house"},
      MAPSEC_SOOTOPOLIS_CITY={"Pokemon Center / Mart / Gym"},
      MAPSEC_PACIFIDLOG_TOWN={"Pokemon Center / Floating town"},
      MAPSEC_EVER_GRANDE_CITY={"Pokemon Center / Pokemon League"},
      MAPSEC_ROUTE_117={"Day Care: two parents / eggs"},
      MAPSEC_BATTLE_FRONTIER={"Battle facilities / BP tutors"},
    }
  end
  local emerald=require("src.core.GameVersion").get()=="emerald"
  local function section()
    if not emerald then return Map.currentMapSec() end
    local state=require("src.ui.game3.rse.region_map").active()
    return state and require("src.core.game3.constants").of("emerald"):name("region_map_sections",state.mapSecId,"MAPSEC_")
  end
  local function rowsFor()
    local rows = {}
    for _, text in ipairs(services[section()] or { "No service notes for this area" }) do
      rows[#rows + 1] = { label = text }
    end
    local R = emerald and require("src.ui.game3.rse.region_map")
    local state = R and R.active()
    if state and state.mode == "fly" then
      local eligible = state.mapSecType == R.TYPE.CITY_CANFLY or state.mapSecType == R.TYPE.BATTLE_FRONTIER
      rows[#rows + 1] = { label = eligible and "FLY: selectable destination" or "FLY: unavailable here" }
    elseif not emerald and Map.isFlyMode() then
      rows[#rows + 1] = { label = Map.canFlyToCursor() and "FLY: selectable destination" or "FLY: unavailable here" }
    else
      rows[#rows + 1] = { label = "Open the native Fly map to fly" }
    end
    rows[#rows + 1] = { label = "Services may require story progress" }
    return rows
  end
  mod.exports.rowsFor = rowsFor
  mod.exports.show = function()
    if not api.active() then return false end
    local Stack=require('src.ui.game3.stack');local top=Stack.top()
    if not top or (top.id~='region_map' and top.id~='rse_region_map') then return false end
    local R=emerald and require('src.ui.game3.rse.region_map');local state=R and R.active()
    if emerald and (not state or state.inputFn=='move')then return false end
    if not emerald and (not Map.open or not Map.inputReady())then return false end
    api.menu(emerald and (state.mapSecName or 'HOENN MAP') or (Map.currentLocationName() or 'TOWN MAP'),rowsFor())
    return true
  end
  if emerald then
    local R=require("src.ui.game3.rse.region_map")
    api.wrap(R,"inputCallback",function(previous,state,input)
      if input.new and input.new.select and state.inputFn~="move" then
        api.menu(state.mapSecName or "HOENN MAP",rowsFor())
        return 0
      end
      return previous(state,input)
    end)
    return
  end
  api.wrap(Map, "handleInput", function(previous, input)
    if Map.open and Map.inputReady() and input:wasPressed("select") then
      api.menu(Map.currentLocationName() or "TOWN MAP", rowsFor())
      return
    end
    return previous(input)
  end)
end
