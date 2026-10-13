return function(mod)
 local Runtime=require('src.mods.Runtime');local owner=Runtime.events
 local Player=require('src.core.game3.player');local Collision=require('src.core.game3.collision')
 mod.options:define({
  {key='enabled',label='ENABLED',type='toggle',default=false},
  {key='key',label='HOLD KEY',type='choice',default='r',choices={{'R','r'},{'F10','f10'},{'F11','f11'},{'LEFT CTRL','lctrl'},{'RIGHT CTRL','rctrl'},{'OFF','off'}}},
  {key='pad',label='HOLD BUTTON',type='choice',default='rightshoulder',choices={{'R / RB','rightshoulder'},{'L / LB','leftshoulder'},{'R3','rightstick'},{'L3','leftstick'},{'OFF','off'}}},
 })
 local held={};local moveGame,moveX,moveY
 local function active()return Runtime.events==owner and mod.options:get('enabled')==true end
 local function ready(g)
  return active() and g and g.session==require('src.core.game3.runtime').getSession() and g.session
   and g.zoomGateOK and g:zoomGateOK() and not require('src.ui.game3.stack').busy()
   and not require('src.ui.game3.help_system').isOpen()
   and not require('src.core.game3.warp').isBusy()
   and not require('src.ui.game3.fade').active
 end
 for _,spec in ipairs({{'input.key','key','key'},{'input.gamepad','pad','button'}})do
  mod.hooks:wrap(spec[1],function(next,g,event)
   local key=event[spec[3]];local token=spec[1]..tostring(event.joystick)..tostring(key)
   if event.phase=='released' then local used=held[token];held[token]=nil;if used then return true end
   elseif event.phase=='pressed' and key==mod.options:get(spec[2]) and key~='off' and ready(g) then
    held[token]={option=spec[2],key=key};return true
   end
   return next(g,event)
  end,21000)
 end
 local function holding()
  for _,v in pairs(held)do if mod.options:get(v.option)==v.key then return true end end
  return false
 end
 local previousMove=Player.tryMove
 local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
 Player.tryMove=function(dir,g,...)
  local d=delta[dir]
  -- Surf must exit through a native shoreline: bypassing elevation checks
  -- can reach dry land without triggering the engine's dismount animation.
  if not d or Player.surfing or Player.underwater or Player.surfHopping or Player.dismounting
   or not ready(g) or not holding() then return previousMove(dir,g,...) end
  moveGame,moveX,moveY=g,Player.cellX+d[1],Player.cellY+d[2]
  local ok,a,b=pcall(previousMove,dir,g,...)
  moveGame,moveX,moveY=nil,nil,nil
  if not ok then error(a,0)end
  return a,b
 end
 local previousEnter=Collision.canEnter
 Collision.canEnter=function(g,x,y,opts)
  local ok,why=previousEnter(g,x,y,opts)
  if not ok and active() and g==moveGame and x==moveX and y==moveY
   and (why=='tile' or why=='elevation' or why=='entity')
   and Collision.inBounds(x,y) and not Collision.isWater(x,y) then return true end
  return ok,why
 end
 -- Release cannot leak into a new game, a menu, or a later focus session.
 mod.hooks:wrap('input.step',function(next,g,dt)
  if not ready(g) then held={} end
  return next(g,dt)
 end,21000)
 mod.events:on('game.ready',function()held={} end)
 mod.events:on('mod.options_changed',function()held={} end)
 local Game=require('src.core.Game3');local focus=Game.focus
 Game.focus=function(g,focused,...)
  if Runtime.events==owner and not focused then held={} end
  return focus(g,focused,...)
 end
end
