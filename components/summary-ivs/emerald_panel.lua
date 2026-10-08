local function collectionSmall()
 local v=require('src.core.GameVersion').get()
 return v~='ruby' and v~='sapphire'
end
-- Emerald's skills page uses two columns, so FRLG's inline IV positions overlap
-- native values. Show the read-only IV/EV table by default; A toggles native stats.
return function(mod,current)
 local Summary=require('src.ui.game3.summary_menu')
 local version=require('src.core.GameVersion').get()
 local rs=version=='ruby' or version=='sapphire'
 local Rse=require(rs and 'src.ui.game3.rs.summary_menu' or 'src.ui.game3.rse.summary_menu')
 local recordKey=rs and '_rsIvs' or '_emeraldIvs'
 local Runtime=require('src.core.game3.runtime')
 local Window=require('src.ui.game3.window')
 local Font=require('src.ui.game3.frlg_font')
 local record=Summary[recordKey]
 if not record then
  record={draw=Rse.draw,input=Summary.handleInput,rseInput=Rse.handleInput}
  Summary[recordKey]=record
  record.open=Summary.openMenu
  Summary.openMenu=function(...)
   record.mon=nil;record.lastMon=nil
   return record.open(...)
  end
  local function sync()
   local mon=record.current()
   if mon~=record.lastMon then record.mon=mon;record.lastMon=mon end
   return mon
  end
  local function handle(previous,input,...)
   local mon=sync()
   if not mon or mon~=record.mon then record.mon=nil end
   if mon and input and input.wasPressed then
    if input:wasPressed('a') then
     if record.mon then record.mon=nil else record.mon=mon end
     return
    end
    if record.mon and input:wasPressed('b') then record.mon=nil;return end
    for _,key in ipairs({'left','right','up','down','l','r','start'}) do
     if input:wasPressed(key) then record.mon=nil;break end
    end
   end
   return previous(input,...)
  end
  Summary.handleInput=function(input,...)return handle(record.input,input,...)end
  Rse.handleInput=function(input,...)return handle(record.rseInput,input,...)end
  Rse.draw=function(...)
   record.draw(...)
   local mon=sync()
   if not mon or record.mon~=mon then record.mon=nil;return end
   local s=Runtime.getSession()
   love.graphics.push('all')
   Window.userFrame(Window.template(2,3,26,15),(s.options or {}).frameType or 0)
   Window.printPx('STAT',26,25,{small=collectionSmall(),colors=Font.COLOR.NORMAL})
   Window.printPx('IV',132,25,{small=collectionSmall(),colors=Font.COLOR.NORMAL})
   Window.printPx('EV',181,25,{small=collectionSmall(),colors=Font.COLOR.NORMAL})
   local stats={{'HP','hp'},{'ATTACK','atk'},{'DEFENSE','def'},{'SP. ATK','spa'},{'SP. DEF','spd'},{'SPEED','spe'}}
   local function value(t,k,max)
    local n=t and t[k]
    return type(n)=='number' and n%1==0 and n>=0 and n<=max and tostring(n) or '--'
   end
   for i,row in ipairs(stats)do
    local y=41+(i-1)*15
    Window.printPx(row[1],26,y,{small=collectionSmall(),colors=Font.COLOR.NORMAL})
    Window.printPx(value(mon.ivs,row[2],31),132,y,{small=collectionSmall(),colors=Font.COLOR.NORMAL})
    Window.printPx(value(mon.evs,row[2],255),181,y,{small=collectionSmall(),colors=Font.COLOR.NORMAL})
   end
   Window.printPx('A / B: native stats',26,130,{small=collectionSmall(),colors=Font.COLOR.NORMAL})
   love.graphics.pop()
  end
 end
 record.current=function()
  local s=Runtime.getSession()
  if not s or (rs and s.version~='ruby' and s.version~='sapphire') or (not rs and s.version~='emerald') or Summary._page~=Summary.PAGE_SKILLS
   or (rs and (Rse._fade or Rse._pageTask or Rse._reload or Rse._state~='normal'))
   or (Summary._slide and Summary._slide.active) then return nil end
  return current()
 end
 record.mon=nil;record.lastMon=nil
 mod.exports.emeraldDetailsOpen=function()return record.mon~=nil and record.current()==record.mon end
end
