-- Components keep their original IDs, options, storage and source bytes.
-- They are not added to loader.mods: the launcher still owns one real mod.
return function(mod)
  local Runtime = require('src.mods.Runtime')
  local owner = Runtime.events
  local definitions = assert(load(mod:read('components.lua'), '@qol-suite/components.lua'))()
  local components, game, loader = {}, nil, nil
  local function active()
    return Runtime.events == owner and mod.find(mod.id) ~= nil
      and mod.options:get('enabled') ~= false
  end
  local Shortcuts = assert(load(mod:read('shortcuts.lua')))()(mod, active)
  mod.options:define(Shortcuts.define({{key='enabled', label='ENABLED', type='toggle', default=true}}))
  local function rawValue(component, key)
    return component.get(component.api.options, key)
  end
  local function suppressed(id)
    local hoenn=require('src.core.game3.profile').active().family=='rse'
    if hoenn and id=='disable-lr-help' then return true end
    if not hoenn and id=='frlg_qol_hoenn_tools' then return true end
    return id=='frlg_qol_ball_shortcut' and loader and loader.mods.frlg_dual_screen~=nil
  end
  function mod.exports.hidden(id) return suppressed(id) and true or false end
  local function available(component)
    return active() and component and component.ready and not suppressed(component.definition.id) and rawValue(component, 'enabled') ~= false
  end
  function mod.exports.find(id)
    local component = components[id]
    if not available(component) then return nil end
    return {id=id, version=component.definition.version, exports=component.api.exports}
  end
  function mod.exports.rows()
    local rows = {}
    if not active() then return rows end
    for _, definition in ipairs(definitions) do
      local component = components[definition.id]
      if not suppressed(definition.id) then
      rows[#rows+1] = {id=definition.id, key='enabled', label=(definition.id=='frlg_qol_vs_seeker_status' and require('src.core.GameVersion').get()=='emerald') and 'Match Call Rematch Status' or ((definition.id=='frlg_qol_vs_seeker_status' and (require('src.core.GameVersion').get()=='ruby' or require('src.core.GameVersion').get()=='sapphire')) and "Trainer's Eyes Rematch Status" or definition.name),
        value=component and component.ready and rawValue(component, 'enabled') ~= false or false,
        error=component and component.error, ready=component and component.ready or false}
      end
    end
    table.sort(rows, function(a,b) return a.label < b.label end)
    return rows
  end
  function mod.exports.schema(id)
    return loader and loader.optionSchemas[id] or {}
  end
  function mod.exports.value(id, key)
    local component = components[id]
    if id == mod.id then return mod.options:get(key) end
    if key=='enabled' and suppressed(id) then return false end
    return component and rawValue(component, key)
  end
  function mod.exports.set(id, key, value)
    local component = components[id]
    if suppressed(id) or not active() or not game or (id ~= mod.id and (not component or not component.ready)) then return false end
    -- One source of truth, including changes made in the companion or an
    -- assistant's own settings screen. The host persists and emits the event.
    local valid = false
    for _, row in ipairs(mod.exports.schema(id)) do
      if row.key == key then
        if row.type == 'toggle' then valid = type(value) == 'boolean'
        elseif row.type == 'text' then valid = type(value) == 'string' and #value <= (row.maxLen or 7)
        elseif row.type == 'choice' then
          for _, choice in ipairs(row.choices or {}) do if choice[2] == value then valid = true end end
        end
      end
    end
    if not valid then return false end
    return require('src.mods.ManagerState').new(game):setOption(id, key, value) ~= false
  end
  local function install(definition)
    local id = definition.id
    local existing = loader.mods[id]
    assert(not (existing and existing.enabled and not existing.failed),
      'Disable the standalone '..definition.name..' and restart before using the suite.')
    local manifest = {}
    for key, value in pairs(mod.manifest) do manifest[key] = value end
    manifest.id, manifest.name, manifest.version = id, definition.name, definition.version
    local api = loader:_api({manifest=manifest, path=mod.path..'/components/'..id})
    local component = {api=api, definition=definition, get=api.options.get, ready=false}
    components[id] = component
    function api.options:get(key)
      if key == 'enabled' and (not active() or not component.ready or suppressed(id)) then return false end
      return rawValue(component, key)
    end
    -- Use the package owner for lifecycle cleanup and error attribution;
    -- preserve each component's original runtime option guards.
    api.hooks = {wrap=function(_, name, callback, priority)
      return mod.hooks:wrap(name, function(nextHook, ...)
        if active() and component.ready
          and (name ~= 'ui.start_menu.items' or rawValue(component, 'enabled') ~= false) then
          return callback(nextHook, ...)
        end
        return nextHook(...)
      end, priority)
    end}
    api.events = {on=function(_, name, callback, priority)
      return mod.events:on(name, function(...)
        if active() and component.ready then return callback(...) end
      end, priority)
    end}
    api.find = function(first, second)
      local other = second or first
      return mod.find(other) or mod.exports.find(other)
    end
    local ok, err = pcall(function()
      local init = assert(load(assert(api:read(definition.entry)), '@'..api.path..'/'..definition.entry))()
      assert(type(init) == 'function', 'Component entry must return an initializer')
      init(api)
      -- Some standalone viewers have no options; the suite still supplies an
      -- individual switch using their original ID and native persistence.
      local hasEnabled=false
      for _,row in ipairs(loader.optionSchemas[id] or {}) do
        if row.key=='enabled' then hasEnabled=true end
      end
      if not hasEnabled then
        local schema={}
        for _,row in ipairs(loader.optionSchemas[id] or {}) do schema[#schema+1]=row end
        table.insert(schema,1,{key='enabled',label='ENABLED',type='toggle',default=true})
        api.options:define(schema)
      end
    end)
    component.ready, component.error = ok, not ok and tostring(err) or nil
    if not ok then
      Runtime.reportError(mod.id, definition.name..': '..tostring(err))
      mod.log:error('QoL component %s failed: %s', id, tostring(err))
    end
  end
  local Menu = assert(load(mod:read('menu.lua'), '@qol-suite/menu.lua'))()(mod, active, Shortcuts)
  mod.exports.show = function() if active() and game then return Menu.show(game) end end
  mod.exports.showShortcuts = function() if active() and game then return Menu.shortcuts(game) end end
  mod.events:on('game.ready', function(payload)
    if loader or Runtime.events ~= owner then return end
    game = payload and payload.game
    loader = game and game.mods
    assert(loader and loader._api, 'Unsupported engine: missing component API factory')
    for _, definition in ipairs(definitions) do install(definition) end
    Shortcuts.install()
  end, 10000)
  local Support = assert(load(mod:read('components/frlg_qol_auto_surf/support.lua')))()
  local ui = Support.new(mod)
  ui.startItem('QOL SETTINGS', function() mod.exports.show() end)
  require('src.ui.game3.start_menu').__frlgQolTools[mod.id..':shortcuts'] = {
    label='QOL SHORTCUTS', active=active, callback=function() mod.exports.showShortcuts() end}
  mod.hooks:wrap('ui.start_menu.items',function(nextHook,currentGame,items)
    local rows=nextHook(currentGame,items)
    if active() and type(rows)=='table' then
      for _,row in ipairs(rows) do
        if row.id=='frlg_qol_tools' then
          row.onSelect=function() return Menu.hub(currentGame) end
        end
      end
    end
    return rows
  end,10000)

end
