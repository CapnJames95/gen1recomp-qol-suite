-- Adapt only each feature's shortcut check. Native handlers receive the original
-- input object, so rebinding a mod never remaps the game's ordinary controls.
return function(mod, active)
  local M={}
  local defs={
    {id='frlg_qol_party_items',label='PARTY HELD ITEMS',button='l',target='src.ui.game3.party_menu',where={'Party list, outside battle.', 'Not eggs or HP animations.'}},
    {id='frlg_qol_party_nickname',label='PARTY NICKNAME',button='select',target='src.ui.game3.party_menu',where={'Party list, outside battle.', 'Selected non-egg Pokemon.'}},
    {id='frlg_qol_party_reminder',label='MOVE REMINDER',button='start',target='src.ui.game3.party_menu',where={'Party list, outside battle.', 'Original move/item rules apply.'}},
    {id='frlg_qol_map_services',label='TOWN MAP SERVICES',button='select',target='src.ui.game3.region_map',where={'Town Map or Fly map.', 'After the map finishes opening.'}},
    {id='frlg_qol_summary_info',label='EXPANDED SUMMARY',button='select',target='src.ui.game3.summary_menu',where={'Your Pokemon Summary, no battle.', 'Not eggs or move selection.'}},
    {id='summary-ivs',label='INSPECTOR IV / EV',button='select',inspector=true,where={'Inside the wild inspector Summary.', 'After the page finishes sliding.'}},
    {id='capture-assistant',label='CAPTURE HELP',button='r',target='src.core.game3.battle.ui',record='__partyAssistants',where={'Supported wild battle command menu.', 'No dialogue or other open panels.'}},
  }
  local gba={{'OFF','off'}}
  for _,key in ipairs({'a','b','select','start','l','r','up','down','left','right'}) do gba[#gba+1]={key:upper(),key} end
  local keys={{'OFF','off'}}
  for _,key in ipairs({'f1','f2','f3','f4','f5','f6','f7','f8','f9','f10','f11','f12','q','e','r','t','y','u','i','o','p','h','j','k','l','n','m','tab','lctrl','rctrl','lshift','rshift'}) do keys[#keys+1]={key:upper(),key} end
  local pads={{'OFF','off'}}
  for _,key in ipairs({'a','b','x','y','back','start','leftshoulder','rightshoulder','leftstick','rightstick','triggerleft','triggerright'}) do pads[#pads+1]={key:upper(),key} end
  function M.define(schema)
    for _,d in ipairs(defs) do
      for _,item in ipairs({{'button','GAME BUTTON',gba,d.button},{'key','EXTRA KEY',keys,'off'},{'pad','EXTRA PAD',pads,'off'}}) do
        schema[#schema+1]={key=d.id..'_'..item[1],label=d.label..' '..item[2],type='choice',choices=item[3],default=item[4]}
      end
    end
    return schema
  end
  local function value(d,kind) return mod.options:get(d.id..'_'..kind) end
  local function proxy(input,d,force)
    if input._qolShortcutId==d.id and not force then return input end
    return setmetatable({_qolShortcutId=d.id,_qolShortcutInput=input,wasPressed=function(_,key)
      if key==d.button then
        if force then return true end
        local bound=value(d,'button')
        return bound and bound~='off' and input:wasPressed(bound) or false
      end
      return not force and input:wasPressed(key) or false
    end}, {__index=function(_,key)
      local v=input[key]
      if type(v)=='function' then return function(_,...) return v(input,...) end end
      return v
    end})
  end
  function M.install()
    for _,d in ipairs(defs) do
      if d.inspector then
        local battle=require('src.core.game3.battle')
        local record=battle._summaryIvsInspector
        local original=record and record.update
        if original then
          record.update=function(dt,game)
            if not active() or not game or not game.input then return original(dt,game) end
            local adapted=setmetatable({input=proxy(game.input,d)}, {__index=game})
            return original(dt,adapted)
          end
          d.invoke=function(input)
            if not mod.exports.find(d.id) then return false end
            local summary=require('src.ui.game3.summary_menu')
            local top=require('src.ui.game3.stack').top()
            if not top or top.mod~=summary or summary._slide.active then return false end
            return original(0,{input=proxy(input,d,true)}) == true
          end
        end
      else
      local target=require(d.target)
      local record=(target[d.record or '__frlgQol'] or {})[d.id..':handleInput']
      if record then
      local handler=record.handler
      record.handler=function(previous,input,...)
        if not input then return handler(previous,input,...) end
        return handler(function() return previous(input._qolShortcutInput or input) end,proxy(input,d),...)
      end
      d.invoke=function(input)
        if not record.active() then return false end
        -- Never invoke a covered underlying screen (naming, mod panels, etc.).
        local top=require('src.ui.game3.stack').top()
        if top and top.mod~=target then return false end
        local passed=false
        handler(function() passed=true end,proxy(input,d,true))
        return not passed
      end
      if d.id=='frlg_qol_party_items' then
        local help=require('src.ui.game3.help_system').__frlgQol[d.id..':update']
        local original=help.handler
        help.handler=function(previous,game)
          if not game or not game.input then return previous(game) end
          local g=setmetatable({input=proxy(game.input,d)}, {__index=game})
          return original(function()return previous(game)end,g)
        end
      end
      end
      end
    end
  end
  local held,axes={},{}
  for _,spec in ipairs({{'input.key','key'},{'input.gamepad','button'}}) do
    local hook,field=spec[1],spec[2]
    mod.hooks:wrap(hook,function(nextHook,game,event)
      local physical,phase=event[field],event.phase
      if hook=='input.gamepad' and phase=='axis' and (event.axis=='triggerleft' or event.axis=='triggerright') then
        physical=event.axis
        local axisToken=tostring(event.joystick)..':'..physical
        local amount=tonumber(event.value) or 0
        if amount>=0.6 and not axes[axisToken] then axes[axisToken]=true;phase='pressed'
        elseif amount<=0.3 and axes[axisToken] then axes[axisToken]=nil;phase='released'
        else
          if held[hook..':'..tostring(event.joystick)..':'..physical] then return true end
          return nextHook(game,event)
        end
      end
      local token=hook..':'..tostring(event.joystick)..':'..tostring(physical)
      if phase=='released' and held[token] then held[token]=nil;return true end
      if held[token] then return true end
      if active() and game and game.phase=='field' and phase=='pressed' and not event.isrepeat then
        for _,d in ipairs(defs) do
          local binding=value(d,hook=='input.key' and 'key' or 'pad')
          if d.invoke and binding~='off' and binding==physical
              and d.invoke(game.input or {wasPressed=function()return false end}) then
            held[token]=true;return true
          end
        end
      end
      return nextHook(game,event)
    end,100)
  end
  mod.hooks:wrap('input.focus',function(nextHook,game,focused)
    if not focused then held={};axes={} end
    return nextHook(game,focused)
  end)
  function M.pages()
    local rows={
      {id='frlg_qol_hold_fast_forward',label='HOLD FAST FORWARD',keys={'key','pad'},where={'Hold during normal gameplay.', 'Release to restore normal speed.'}},
      {id='frlg_qol_ball_shortcut',label='BALL SHORTCUT',keys={'key','pad','select'},where={'Wild battle command menu.', 'SELECT follows game controls.'}},
      {id='summary-ivs',label='WILD INSPECTOR',keys={'inspect_key','inspect_pad'},where={'Single wild battle command menu.', 'No Safari, link or tutorials.'}},
    }
    for _,d in ipairs(defs) do
      rows[#rows+1]={id=mod.id,label=d.label,feature=d.id,keys={d.id..'_button',d.id..'_key',d.id..'_pad'},where=d.where}
    end
    for i=#rows,1,-1 do
      if mod.exports.hidden(rows[i].id) then table.remove(rows,i) end
    end
    return rows
  end
  return M
end
