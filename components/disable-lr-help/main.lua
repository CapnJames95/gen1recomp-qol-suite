return function(mod)
  local Mods = require('src.mods.Runtime')
  local Version = require('src.core.GameVersion')
  local Help = require('src.ui.game3.help_system')
  local Game = require('src.core.Game3')
  local owner = Mods.events
  mod.options:define({{key='enabled', label='ENABLED', type='toggle', default=true}})

  local function active()
    local version = Version.get()
    return owner == Mods.events and mod.options:get('enabled') ~= false
      and (version == 'firered' or version == 'leafgreen')
  end

  local function wrap(target, name, handler)
    target._disableLrHelp = target._disableLrHelp or {}
    local record = target._disableLrHelp[name]
    if not record then
      record = {previous=assert(target[name])}
      target._disableLrHelp[name] = record
      target[name] = function(...)
        if record.active() then return record.handler(record.previous, ...) end
        return record.previous(...)
      end
    end
    record.active, record.handler = active, handler
  end

  wrap(Help, 'show', function() return false end)
  wrap(Help, 'update', function(previous, game)
    if Help.isOpen() then Help.close() end
    return previous(game)
  end)
  wrap(Game, '_aliasLA', function(previous, game)
    local result = previous(game)
    if game.input and game.input.setButtonAlias then game.input:setButtonAlias('l', nil) end
    return result
  end)
end
