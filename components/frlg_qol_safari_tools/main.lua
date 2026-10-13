return function(mod)
 local function module(n)return assert(load(assert(mod:read(n..'.lua')),'@safari-tools/'..n))()end
 local E=module('runtime')(mod);local M=module('model');local Menu=module('menu')(module('view'))
 local Safari=require('src.core.game3.safari');local Runtime=require('src.core.game3.runtime');local Battle=require('src.core.game3.battle')
 local steps={{'Normal',1},{'x2',2},{'x5',5},{'Unlimited',0}};local balls={{'Normal',30},{'50',50},{'99',99},{'Unlimited',0}}
 mod.options:define({{key='enabled',label='ENABLED',type='toggle',default=true},
  {key='steps',label='SAFARI STEPS',type='choice',default=1,choices=steps},
  {key='balls',label='SAFARI BALLS',type='choice',default=30,choices=balls}})
 local function settings()return E.get('steps'),E.get('balls')end
 local promptSession,prompt,heldField
 local function pending(s,reason)M.data(s).pending=reason end
 local function release()
  if heldField then require('src.core.game3.field').locked=heldField.previous;heldField=nil end
  promptSession=nil;if prompt then prompt.close();prompt=nil end
 end
 local function stopHunter()
  local hunter=mod.find('shiny_hunter');if hunter and hunter.exports and hunter.exports.stopForSafari then hunter.exports.stopForSafari()end
 end
 local function retire(s,game)
  stopHunter()
  M.data(s).pending=nil;M.data(s).retire=true;release()
  if Battle.isActive()then Battle.abort('run')end
 end
 local function depletion(s,game)
  if prompt or not M.data(s).pending then return end
  local hunter=mod.find('shiny_hunter');if hunter and hunter.exports and hunter.exports.suspendForSafari then hunter.exports.suspendForSafari()end
  promptSession=s
  local Field=require('src.core.game3.field');heldField={previous=Field.locked};Field.locked=true
  local ui=Menu.new(mod.id,s,function()return E.active(s)end);prompt=ui
  local function refill()
   if not E.active(s) then release();return end
   M.refill(s,settings())
   local hunter=mod.find('shiny_hunter');if hunter and hunter.exports and hunter.exports.safariRefilled then hunter.exports.safariRefilled(s)end
   release()
  end
  ui.push(M.data(s).pending=='balls' and 'SAFARI BALLS EMPTY' or 'SAFARI STEPS ENDED',{
   {label='Refill balls and steps',action=refill},
   {label='Retire from Safari',action=function()retire(s,game)end},
   {label='Choose before continuing.'}})
  -- No dismissal back into the field with a depleted counter.
  local handle=ui.handleInput
  ui.handleInput=function(input)
   if input and (input:wasPressed('b') or input:wasPressed('l') or input:wasPressed('start'))then return end
   return handle(input)
  end
 end
 E.wrap(Safari,'enter',function(previous,s,...)
  local result=previous(s,...);s=s or Runtime.getSession()
  if result and E.active(s) then M.refill(s,settings())end
  return result
 end)
 E.wrap(Safari,'takeStep',function(previous,s,game,...)
  s=s or Runtime.getSession()
  if not E.active(s) or not Safari.isActive(s) then return previous(s,game,...)end
  local state=s.safari;local original=tonumber(state.steps)or 0
  if M.data(s).pending then return false end
  if E.get('steps')==0 and original>0 then state.steps=original+1
  elseif original<=1 then
   -- Native step processing still ages Hoenn feeders, but cannot fire times-up.
   state.steps=2;local result=previous(s,game,...);pending(s,'steps');return result
  end
  return previous(s,game,...)
 end)
 E.wrap(require('src.core.game3.battle.catching'),'tryCatch',function(previous,item,enemy,st,s,...)
  if item==5 and st and st.safari and st.safariState and s and E.active(s) and Safari.isActive(s) then
   if E.get('balls')==0 then st.safariState.balls=st.safariState.balls+1;s.safari.balls=st.safariState.balls
   elseif st.safariState.balls<=0 then
    -- Defer native out-of-balls retirement until the final throw is resolved.
    st.safariState.balls=1;s.safari.balls=1;pending(s,'balls')
   end
  end
  return previous(item,enemy,st,s,...)
 end)
 local function show(s)
  s=s or Runtime.getSession();if not E.active(s)then return end
  local ui=Menu.new(mod.id,s,function()return E.active(s)end)
  local function cycle(key,choices)
   for i,row in ipairs(choices)do if row[2]==E.get(key) then E.set(key,choices[i%#choices+1][2]);return end end
  end
  local function label(key,choices)for _,r in ipairs(choices)do if r[2]==E.get(key)then return r[1]end end;return 'Normal'end
  ui.push('SAFARI TOOLS',{
   {label=function()return M.status(s,settings())end},
   {label=function()return 'Steps: '..label('steps',steps)end,action=function()cycle('steps',steps)end},
   {label=function()return 'Balls: '..label('balls',balls)end,action=function()cycle('balls',balls)end},
   {label='Refill current Safari game',action=function()local ok,why=E.ready(s);if ok then ok,why=M.refill(s,settings())end;if not ok then ui.info('SAFARI TOOLS',{why})end end},
   {label='Wild Pokemon checklist',action=function()
    local ds=mod.find('frlg_dual_screen');if ds and ds.exports and ds.exports.showWildPokemon then ui.close();if not ds.exports.showWildPokemon()then local again=show(s);if again then again.info('SAFARI TOOLS',{'Close other menus and try again.'})end end else ui.info('SAFARI TOOLS',{'Enable Gen3DualScreen for its local encounter checklist.'})end
   end},
   {label='Retire from Safari',action=function()if E.ready(s) and Safari.isActive(s)then stopHunter();ui.close();Safari.retirePrompt(s,E.game or Runtime._game)end end},
   {label='Help',action=function()ui.info('SAFARI TOOLS',{'Allowances apply at entry or when refilling. Unlimited stops depletion; catch rates and fleeing stay native. At zero, choose Refill or Retire before the normal time-up message. Shiny Hunter pauses for this choice. Save normally to retain settings.'})end},
   {label='Back',action=ui.close}})
  return ui
 end
 E.start('SAFARI TOOLS',show)
 mod.hooks:wrap('input.step',function(next,game,dt)
  E.game=game;local s=Runtime.getSession()
  if promptSession and (s~=promptSession or not E.active(s))then release()end
  if E.active(s) and M.data(s).retire and not Battle.isActive() and not require('src.ui.game3.fade').isActive() then
   M.data(s).retire=nil
   if Safari.isActive(s) then
    s.safari.steps=0
    local cfg=Safari.rseConfig(s)
    if cfg then
     local Space=require('src.core.game3.scripting.space');local key=Space.scriptKey(cfg.timesUp)
     if key then Space.startScript(key)else s.safari.steps=1;pending(s,'steps')end
    else Safari.timesUp(s,game)end
   end
  end
  if E.active(s) and Safari.isActive(s) and M.data(s).pending and not prompt then
   local busy=require('src.ui.game3.fade').isActive() or require('src.core.game3.battle_transition').isActive()
    or require('src.core.game3.player').moving or require('src.ui.game3.naming').isOpen()
    or require('src.ui.game3.message').isOpen() or require('src.ui.game3.choice').active
   local st=Battle.getState();local ui=require('src.core.game3.battle.ui')
   if not busy and (not Battle.isActive() or (Battle._phase=='command' and not ui.busy() and not (st and st.over)))then depletion(s,game)end
  end
  return next(game,dt)
 end,20000)
 mod.exports.counterLabel=function()
  local s=Runtime.getSession();if not E.active(s) or not Safari.isActive(s)then return nil end
  local pending=M.data(s).pending
  return 'SAFARI B:'..(E.get('balls')==0 and 'INF' or tostring(pending=='balls' and 0 or s.safari.balls))..' S:'..(E.get('steps')==0 and 'INF' or tostring(pending=='steps' and 0 or s.safari.steps))
 end
 mod.exports.show=show;mod.exports.status=function()local s=Runtime.getSession();return E.active(s) and M.status(s,settings()) or 'Safari: inactive'end
end
