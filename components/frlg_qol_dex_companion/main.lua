return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  local api = Support.new(mod)
  local Pokemon = require("src.core.game3.pokemon")
  local Dex = require("src.core.game3.dex")
  local DexData = require("src.core.game3.pokedex_data")
  local Encounters = require("src.core.game3.encounters")
  local Naming = require("src.ui.game3.naming")
  local Items = require("src.core.game3.items_data")
  local methods = require("src.mods.Schemas").gen3View.EVOLUTIONS
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "unseen", label = "SHOW UNSEEN", type = "toggle", default = false },
  })
  local function marked(which, species)
    local session = api.session()
    local dex = session and session.dex
    return which == "owned" and Dex.isOwned(dex, species) or which == "seen" and Dex.isSeen(dex, species)
  end
  local function details(species)
    local rows = {}
    local evolutions = Pokemon.evolutions(species)
    for _, evolution in ipairs(evolutions) do
      local method = tonumber(evolution.method or evolution[1])
      local param = tonumber(evolution.param or evolution[2]) or 0
      local target = tonumber(evolution.target or evolution[3])
      rows[#rows + 1] = { label = "Evolves: " .. Pokemon.name(target) }
      local label = tostring(methods[method] or method):gsub("^EVO_", ""):gsub("_", " ")
      if method == 6 or method == 7 then label = label .. ": " .. Items.displayName(param)
      elseif param > 0 then label = label .. ": " .. param end
      rows[#rows + 1] = { label = label }
    end
    if #evolutions == 0 then rows[#rows + 1] = { label = "No recorded evolution" } end
    local areas = DexData.getWildAreasForSpecies(species)
    rows[#rows + 1] = { label = "Wild locations (imported data):" }
    for _, area in ipairs(areas) do
      rows[#rows + 1] = { label = tostring(area):gsub("^DEX_AREA_", ""):gsub("_", " ") }
    end
    if #areas == 0 then rows[#rows + 1] = { label = "No recorded wild location" } end
    api.menu(Pokemon.name(species), rows)
  end
  local function speciesList(query)
    query = tostring(query or ""):upper()
    local list = {}
    for _, record in mod.content.pokemon:each() do
      local species = tonumber(record.gen3Species or record.index)
      if species and (mod.options:get("unseen") or marked("seen", species) or marked("owned", species)) then
        local name = tostring(record.name or Pokemon.name(species))
        if name:upper():find(query, 1, true) then list[#list + 1] = { species = species, name = name } end
      end
    end
    table.sort(list, function(left, right)
      if left.name ~= right.name then return left.name < right.name end
      return left.species < right.species
    end)
    local rows = {}
    for _, record in ipairs(list) do
      local species = record.species
      rows[#rows + 1] = { label = (marked("owned", species) and "[OWN] "
        or marked("seen", species) and "[SEEN] " or "[---] ") .. record.name,
        choose = function() details(species) end }
    end
    if #rows == 0 then rows[1] = { label = "No matching seen Pokemon" } end
    api.menu("DEX SEARCH: " .. query, rows)
  end
  local function routeSpecies(header)
    local found, visited = {}, {}
    local function walk(value)
      if type(value) ~= "table" or visited[value] then return end
      visited[value] = true
      local species = tonumber(value.species)
      if species and species > 0 then found[species] = true end
      for _, child in pairs(value) do if type(child) == "table" then walk(child) end end
    end
    walk(header)
    local species = {}
    for id in pairs(found) do species[#species + 1] = id end
    table.sort(species)
    return species
  end
  mod.exports.routeSpecies = routeSpecies
  local function route()
    local session = api.session()
    local species = routeSpecies(session and Encounters.tableFor(session.map))
    local rows, count = {}, 0
    for _, id in ipairs(species) do
      local chosen = id
      local owned = marked("owned", id)
      if owned then count = count + 1 end
      local visible = owned or marked("seen", id) or mod.options:get("unseen")
      rows[#rows + 1] = { label = (owned and "[OWN] " or "[---] ")
        .. (visible and Pokemon.name(id) or "Unseen species"),
        choose = visible and function() details(chosen) end or nil }
    end
    if #species == 0 then rows[1] = { label = "No ordinary encounters recorded" } end
    api.menu(("AREA DEX: %d/%d OWNED"):format(count, #species), rows)
  end
  api.startItem("DEX COMPANION", function()
    api.menu("DEX COMPANION", {
      { label = "SEARCH BY NAME", choose = function()
        Naming.open({ title = "SEARCH NAME", maxLen = 10, template = "PLAYER",
          onDone = function(query) speciesList(query) end })
      end },
      { label = "LIST SEEN / OWNED", choose = function() speciesList("") end },
      { label = "CURRENT AREA COMPLETION", choose = route },
    })
  end)
end
