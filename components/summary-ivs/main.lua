local function collectionSmall()
 local v=require('src.core.GameVersion').get()
 return v~='ruby' and v~='sapphire'
end
return function(mod)
  local Summary = require('src.ui.game3.summary_menu')
  local Font = require('src.ui.game3.frlg_font')
  local Pokemon = require('src.core.game3.pokemon')
  local Runtime = require('src.core.game3.runtime')
  local Mods = require('src.mods.Runtime')
  local owner = Mods.events
  local stats = {{'hp',20}, {'atk',38}, {'def',51}, {'spa',64}, {'spd',77}, {'spe',90}}
  mod.options:define({
    {key='enabled', label='SHOW IVS', type='toggle', default=true},
    {key='inspect', label='WILD INSPECTOR', type='toggle', default=true},
    {key='inspect_key', label='INSPECT KEY', type='text', default='i', maxLen=24},
    {key='inspect_pad', label='INSPECT BUTTON', type='choice', default='x',
      choices={{'Y / NORTH','y'},{'X / WEST','x'},{'A / SOUTH','a'},{'B / EAST','b'},
        {'LB / L1','leftshoulder'},{'RB / R1','rightshoulder'},
        {'LT / L2','triggerleft'},{'RT / R2','triggerright'},
        {'L3 / LEFT STICK','leftstick'},{'R3 / RIGHT STICK','rightstick'},
        {'D-PAD UP','dpup'},{'D-PAD DOWN','dpdown'},{'D-PAD LEFT','dpleft'},{'D-PAD RIGHT','dpright'},
        {'BACK / SHARE','back'},{'START / MENU','start'},{'GUIDE / HOME','guide'},{'OFF','off'}}},
  })
  local inspect = assert(load(assert(mod:read('inspector.lua')), '@summary-ivs/inspector.lua'))()(mod,
    function() return owner == Mods.events and mod.options:get('enabled') ~= false end)

  local function current()
    local session = Runtime.getSession()
    local S=Summary._nativeDelegate or Summary
    if owner ~= Mods.events or mod.options:get('enabled') == false or not session
      or (session.version ~= 'firered' and session.version ~= 'leafgreen' and session.version ~= 'emerald' and session.version ~= 'ruby' and session.version ~= 'sapphire')
      or not S.open or ((S._enemyParty or (S._opts and S._opts.enemyParty)) and not inspect()) or S._mode == 'select_move' or S._mode==2 or S._mode==3
      or (S._playerState and S._playerState ~= session and not inspect()) then return nil end
    local mon = S._party and S._party[S._cursor]
    if type(mon) ~= 'table' or Pokemon.isEgg(mon) then return nil end
    return mon
  end

  local function rows()
    local mon = current()
    if not mon or Summary._page ~= Summary.PAGE_SKILLS
      or (Summary._slide and Summary._slide.active) then return {} end
    local _, evs = inspect()
    local values = mon.ivs
    if evs then values = mon.evs end
    values = type(values) == 'table' and values or {}
    local result = {}
    for _, stat in ipairs(stats) do
      local value = values[stat[1]]
      local valid = type(value) == 'number' and value >= 0 and value <= (evs and 255 or 31) and value % 1 == 0
      result[#result+1] = {key=stat[1], text=(evs and 'EV' or 'IV ')..(valid and tostring(value) or '--'), x=168, y=stat[2]-2}
    end
    return result
  end

  local record = Summary._summaryIvs
  if not record then
    record = {previous=Summary.draw}
    Summary._summaryIvs = record
    Summary.draw = function(...)
      record.drawing = true
      local ok, result = pcall(record.previous, ...)
      record.drawing = false
      if not ok then error(result, 0) end
      local session=Runtime.getSession()
      for _, row in ipairs(session and require('src.core.game3.profile').forSession(session).family=='rse' and {} or record.rows()) do
        Font.draw(row.text, row.x, row.y, {small=collectionSmall(), colors=Font.COLOR.NORMAL})
      end
      return result
    end
  end
  local RomText = require('src.core.game3.rom_text')
  if not record.previousText then
    record.previousText = RomText.plain
    RomText.plain = function(key, ...)
      if record.drawing and record.preview() then
        if key == 'gText_PokeSum_PageName_PokemonSkills' then return 'POKéMON PREVIEW' end
        if key == 'gText_PokeSum_Controls_Page' then
          local _, nature = require('src.core.game3.summary_data').nature(record.preview())
          return nature or '--'
        end
      end
      return record.previousText(key, ...)
    end
  end
  record.preview = function() return inspect() end
  record.rows = rows
  record.nativePanel = function()
    return current() ~= nil and (Summary._page == Summary.PAGE_SKILLS
      or (Summary._slide and Summary._slide.active and Summary._slide.prevPage == Summary.PAGE_SKILLS))
  end
  assert(load(assert(mod:read('emerald_panel.lua')),'@summary-ivs/emerald_panel.lua'))()(mod,current)
  mod.exports.rows = rows
end
