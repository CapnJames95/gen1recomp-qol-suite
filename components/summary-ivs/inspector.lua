return function(mod, active)
  local Battle = require('src.core.game3.battle')
  local Ui = require('src.core.game3.battle.ui')
  local Summary = require('src.ui.game3.summary_menu')
  local Stack = require('src.ui.game3.stack')
  local Runtime = require('src.core.game3.runtime')
  local Help = require('src.ui.game3.help_system')
  local inspected, held, axes = nil, {}, {}
  local function binding(option)
    local value = mod.options:get(option)
    if type(value) ~= 'string' then return 'off' end
    value = value:lower():match('^%s*(.-)%s*$')
    if value == '' then return 'off' end
    local aliases = {enter='return',esc='escape',ctrl='lctrl',shift='lshift',alt='lalt',cmd='lgui'}
    return aliases[value] or value
  end
  local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
  end
  local function enabled()
    local session = Runtime.getSession()
    return active() and mod.options:get('inspect') ~= false and session
      and (session.version == 'firered' or session.version == 'leafgreen' or session.version == 'emerald' or session.version == 'ruby' or session.version == 'sapphire')
  end
  local function valid()
    return inspected and enabled() and Runtime.getSession() == inspected.session
      and Battle.isActive() and Battle._st == inspected.state and Ui._st == inspected.state
      and Ui._st.enemy and Ui._st.enemy.mon == inspected.original
      and Summary.open and (Summary._nativeDelegate or Summary)._party == inspected.party and Stack.has('summary')
  end
  local function close()
    local previous = inspected
    inspected = nil
    if previous and (Summary._nativeDelegate or Summary)._party == previous.party and Summary.open then Summary.close() end
  end
  local function ready()
    local state = Ui._st
    return enabled() and Battle.isActive() and state and Battle._st == state and state.wild
      and not state.double and not state.link and not state.spectate and not state.safari
      and not state.oldManTutorial and not state.pokedude and not state.ghostBattle
      and state.enemy and state.enemy.mon and (tonumber(state.enemy.mon.hp) or 0) > 0
      and Ui._mode == 'menu' and not Ui._headless and not Ui._showing
      and not Ui._pendingCommand and not Stack.busy() and not Summary.open and not Help.isOpen()
  end
  local function open()
    if not ready() then return false end
    local state, session = Ui._st, Runtime.getSession()
    local party = {copy(state.enemy.mon)}
    party[1].status = state.enemy.status
    if state.enemy.item ~= nil then party[1].item=state.enemy.item;party[1].heldItem=state.enemy.item end
    if state.enemy.ability ~= nil then party[1].ability=state.enemy.ability;party[1].abilityId=state.enemy.ability end
    local playerState = {}
    for _, key in ipairs({'version','name','playerName','trainerId','otId','id','secretId','otSecretId','map','options','flags'}) do
      playerState[key] = copy(session[key])
    end
    inspected = {state=state,session=session,original=state.enemy.mon,party=party,evs=false}
    local ok, err = pcall(Summary.openMenu, party, 1, {session=playerState,enemyParty=true,
      page=Summary.PAGE_SKILLS,onClose=function() inspected=nil end})
    if not ok then close(); error(err,0) end
    return true
  end
  local function bind(hook, field, option)
    mod.hooks:wrap(hook, function(nextHook, game, event)
      local value = event[field]
      local phase = event.phase
      if hook == 'input.gamepad' and phase == 'axis'
          and (event.axis == 'triggerleft' or event.axis == 'triggerright') then
        value = event.axis
        local axisToken = tostring(event.joystick) .. ':' .. value
        local amount = tonumber(event.value) or 0
        if amount >= 0.6 and not axes[axisToken] then
          axes[axisToken] = true
          phase = 'pressed'
        elseif amount <= 0.3 and axes[axisToken] then
          axes[axisToken] = nil
          phase = 'released'
        else
          if held[hook .. ':' .. axisToken] then return true end
          return nextHook(game,event)
        end
      end
      local token = hook .. ':' .. tostring(event.joystick) .. ':' .. tostring(value)
      if phase == 'released' and held[token] then held[token]=nil;return true end
      if phase == 'pressed' and held[token] then return true end
      if phase == 'pressed' and not event.isrepeat and value ~= 'off'
          and value == binding(option) and game and game.phase == 'field'
          and game.session == Runtime.getSession() then
        if valid() then close();held[token]=true;return true end
        if open() then held[token]=true;return true end
      end
      return nextHook(game,event)
    end)
  end
  bind('input.key','key','inspect_key')
  bind('input.gamepad','button','inspect_pad')
  mod.hooks:wrap('input.step',function(nextHook,game,dt)
    if inspected and not valid() then close() end
    return nextHook(game,dt)
  end)
  mod.hooks:wrap('input.focus',function(nextHook,game,focused)
    if not focused then close();held={};axes={} end
    return nextHook(game,focused)
  end)
  local record = Battle._summaryIvsInspector
  if not record then
    record = {previous=Battle.update}
    Battle._summaryIvsInspector = record
    Battle.update = function(dt,game)
      if record.update(dt,game) then return end
      return record.previous(dt,game)
    end
  elseif record.close then
    record.close()
  end
  record.close = close
  record.update = function(dt,game)
    if not inspected then return false end
    if not valid() then close();return true end
    Summary.update(dt)
    local input = game and game.input
    if input then
      if input:wasPressed('select') and not (Summary._slide and Summary._slide.active) and not (Summary._nativeDelegate and (Summary._nativeDelegate._pageTask or Summary._nativeDelegate._fade or Summary._nativeDelegate._reload)) then
        inspected.evs = not inspected.evs
      else
        Summary.handleInput(input)
      end
    end
    return true
  end
  mod.exports.inspect = open
  return function()
    if valid() then return inspected.party[1], inspected.evs end
  end
end
