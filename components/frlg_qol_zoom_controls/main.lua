return function(mod)
 local Runtime=require('src.mods.Runtime');local owner=Runtime.events
 local Zoom=require('src.render.Zoom');local Renderer=require('src.render.Renderer')
 local Map=require('src.core.game3.map');local Dataset=require('src.core.game3.dataset')
 local choices={};for n=-12,12 do choices[#choices+1]={n==0 and 'FIT' or (n<0 and 'OUT '..-n or 'IN '..n),n}end
 mod.options:define({
  {key='enabled',label='ENABLED',type='toggle',default=true},
  {key='key',label='ZOOM KEY',type='choice',default='f10',choices={{'OFF','off'},{'F10','f10'},{'F11','f11'},{'4','4'},{'Z','z'},{'C','c'},{'V','v'}}},
  {key='pad',label='ZOOM BUTTON',type='choice',default='off',choices={{'OFF','off'},{'R3','rightstick'},{'L3','leftstick'},{'Y','y'},{'X','x'},{'LB','leftshoulder'},{'RB','rightshoulder'},{'BACK','back'}}},
  {key='mode',label='HOTKEY MODE',type='choice',default='cycle',choices={{'CYCLE LEVELS','cycle'},{'TOGGLE TWO','toggle'}}},
  {key='first',label='TOGGLE LEVEL 1',type='choice',default=0,choices=choices},
  {key='second',label='TOGGLE LEVEL 2',type='choice',default=-2,choices=choices},
  {key='automatic',label='INDOOR / OUTDOOR ZOOM',type='toggle',default=false},
  {key='indoor',label='INDOOR LEVEL',type='choice',default=0,choices=choices},
  {key='outdoor',label='OUTDOOR LEVEL',type='choice',default=-2,choices=choices},
 })
 local held={};local session,area,config,baseline,last
 local function active()return Runtime.events==owner and mod.options:get('enabled')~=false end
 local function ready(g)
  return active() and g and g.session and g.session==require('src.core.game3.runtime').getSession()
   and g.zoomGateOK and g:zoomGateOK() and not require('src.ui.game3.stack').busy()
   and not require('src.ui.game3.help_system').isOpen() and not require('src.ui.game3.fade').active
 end
 local function apply(value)
  if baseline==nil then baseline=Zoom.offset end
  Zoom.offset=Zoom.clampOffset(value,Renderer:fitScale());last=Zoom.offset
 end
 local function hotkey(g)
  if not ready(g) then return false end
  if session~=g.session then session=g.session;area=nil;config=nil;baseline=nil;last=nil end
  local scale=Renderer:fitScale()
  if mod.options:get('mode')=='toggle' then
   local a=Zoom.clampOffset(mod.options:get('first'),scale)
   local b=Zoom.clampOffset(mod.options:get('second'),scale)
   apply(Zoom.offset==a and b or a)
  else
   local lo,hi=Zoom.offsetRange(scale);local n=Zoom.offset+1;apply(n>hi and lo or n)
  end
  return true
 end
 for _,spec in ipairs({{'input.key','key','key'},{'input.gamepad','pad','button'}})do
  mod.hooks:wrap(spec[1],function(next,g,event)
   local key=event[spec[3]];local token=spec[1]..tostring(event.joystick)..tostring(key)
   if event.phase=='released' then local used=held[token];held[token]=nil;if used then return true end
   elseif event.phase=='pressed' and key==mod.options:get(spec[2]) and key~='off' then
    if held[token] then return true end
    if hotkey(g) then held[token]=true;return true end
   end
   return next(g,event)
  end,19000)
 end
 mod.hooks:wrap('input.step',function(next,g,dt)
  if not active() then
   if baseline~=nil and Zoom.offset==last then Zoom.offset=baseline end
   baseline,last,session,area,config=nil,nil,nil,nil,nil;held={}
  elseif ready(g) then
   if session~=g.session then session=g.session;area=nil;config=nil;baseline=nil end
   local def=g.data and g.data.maps and g.data.maps[Map.current]
   local kind=def and (Dataset.isOutdoorMapType(def.mapType) and 'outdoor'
    or ((Dataset.isIndoorMapType(def.mapType) or tonumber(def.mapType)==4) and 'indoor'))
   local signature=tostring(mod.options:get('automatic'))..':'..tostring(mod.options:get('indoor'))..':'..tostring(mod.options:get('outdoor'))
   if kind and mod.options:get('automatic') and (kind~=area or config~=signature) then apply(mod.options:get(kind)) end
   area,config=kind,signature
  end
  return next(g,dt)
 end,900)
 mod.events:on('game.ready',function()held={};session,area,config,baseline,last=nil,nil,nil,nil,nil end)
 local Game=require('src.core.Game3');local focus=Game.focus
 Game.focus=function(g,focused,...)
  if Runtime.events==owner and not focused then held={} end
  return focus(g,focused,...)
 end
end
