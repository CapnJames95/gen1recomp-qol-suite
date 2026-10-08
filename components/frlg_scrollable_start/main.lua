-- Keep the host's input, callbacks, Safari panel and exit confirmation.
return function(mod)
  local Menu = require('src.ui.game3.start_menu')
  local Window = require('src.ui.game3.window')
  local Font = require('src.ui.game3.frlg_font')
  local Display = require('src.core.game3.display')
  local Runtime = require('src.mods.Runtime')
  local Version = require('src.core.GameVersion')
  local owner = Runtime.events
  mod.options:define({{key='enabled', label='ENABLED', type='toggle', default=true}})
  local first, drawing, installed = 1, false, nil
  local function active()
    local version = Version.get()
    return Runtime.events == owner and mod.options:get('enabled') ~= false
      and (version == 'firered' or version == 'leafgreen' or version == 'emerald' or version == 'ruby' or version == 'sapphire')
  end
  local function module(name)
    return assert(load(assert(mod:read(name..'.lua')), '@frlg_scrollable_start/'..name..'.lua'))()
  end
  local organizer = module('organizer')(mod, active, module('layout'))
  local function install()
    Menu._frlgStartRenderer = active
    if Menu.draw == installed then return end
    local previous = Menu.draw
    installed = function(...)
      organizer.sync()
      if drawing or not active() or not Menu.open then return previous(...) end
      if not Menu._frlgStartPreview and Menu._frlgHideStartMenu and Menu._frlgHideStartMenu() then return end
      local entries, cursor, template = Menu.ENTRIES, Menu.cursor, Menu.contentTemplate
      local tile = Display.TILE
      local pitch = (Menu._data and Menu._data.rowPitch) or Window.OPTION_HEIGHT
      local textY = (Menu._data and Menu._data.textY) or 0
      local maxTiles = math.floor(Display.H / tile) - 2 -- include both frame edges
      local nativeLimit = (Menu._data and Menu._data.maxVisible) or Menu.MAX_VISIBLE or 8
      local capacity = math.min(nativeLimit, math.max(1, math.floor((maxTiles * tile - textY) / pitch)))
      local count = math.min(#entries, capacity)
      first = math.max(1, math.min(first, #entries - count + 1))
      if cursor < first then first = cursor end
      if cursor >= first + count then first = cursor - count + 1 end
      first = math.max(1, first)
      local width = 7
      for _, entry in ipairs(entries) do
        width = math.max(width, math.ceil((Font.measure(entry.label) + Window.CURSOR_WIDTH + 4) / tile))
      end
      local cols = math.floor(Display.W / tile)
      width = math.min(width, cols - 2)
      -- Leave the native Safari statistics panel unobscured.
      if Menu._safariStats then width = math.min(width, cols - 13) end
      local view = {}
      for i = first, first + count - 1 do view[#view + 1] = entries[i] end
      local height = math.max(2, math.ceil((textY + math.max(1, count) * pitch) / tile))
      local tpl = Window.template(cols - width - 1, 1, width, height)
      Menu._frlgStartGeometry={width=(width+2)*tile,height=(height+2)*tile}
      drawing = true
      local scroll = Menu._scrollOffset
      Menu.ENTRIES, Menu.cursor = view, cursor - first + 1
      Menu._scrollOffset = 0 -- the view has already been scrolled by this renderer
      Menu.contentTemplate = function() return tpl end
      local ok, err = pcall(previous, ...)
      -- Restore even after a renderer error: input always sees the complete list.
      Menu.ENTRIES, Menu.cursor, Menu.contentTemplate = entries, cursor, template
      Menu._scrollOffset = scroll
      drawing = false
      if not ok then error(err, 0) end
      if #entries > count and not Menu._confirmExit then
        local g = love.graphics
        g.push('all')
        g.setColor(0.2, 0.2, 0.2, 1)
        local x = (tpl.left + width) * tile + 2
        local y, h = tile, height * tile
        g.rectangle('fill', x, y, 1, h)
        local thumb = math.max(3, h * count / #entries)
        local offset = (h - thumb) * (first - 1) / (#entries - count)
        g.rectangle('fill', x - 1, y + offset, 3, thumb)
        g.pop()
      end
    end
    Menu.draw = installed
  end
  install()
  -- Install after other mods' startup wrappers, independent of load order.
  mod.hooks:wrap('ui.start_menu.items', function(nextHook, ...)
    local entries = nextHook(...)
    if active() then first = 1; install() end
    return entries
  end)
end
