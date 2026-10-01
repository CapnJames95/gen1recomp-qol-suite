return function(mod, active, A, organizer)
  local Menu=require('src.ui.game3.start_menu')
  local Stack=require('src.ui.game3.stack')
  local Display=require('src.core.game3.display')
  local Window=require('src.ui.game3.window')
  local E={}
  local draft,session,contact,boundGame,patches,saveFailed
  local id='frlg_scrollable_start:appearance'
  local screen={startAppearanceEditor=true}
  local function valid()
    return draft and active() and Menu.open and Menu._session==session
      and Stack.top() and Stack.top().mod==screen
  end
  local function release()
    for _,p in ipairs(patches or {})do if boundGame[p.key]==p.fn then boundGame[p.key]=p.old end end
    patches=nil;boundGame=nil
  end
  local function close()
    draft=nil;contact=nil;Stack.pop(id);release()
  end
  local function save()
    if not valid() then close();return end
    local value=A.clean(draft)
    -- The organizer reports storage failures; keep the unsaved draft to retry.
    if organizer.saveAppearance(value) then close() else saveFailed=true end
  end
  local function geometry()
    local m=Menu._frlgStartGeometry or {width=136,height=152}
    return m.width,m.height,A.bounds(draft,m.width,m.height)
  end
  function E.value()
    if draft and (not active() or not Menu.open or Menu._session~=session)then close()end
    return draft or organizer.appearance()
  end
  E.cancel=close
  function screen.handleInput(input)
    if not valid() then close();return end
    local key
    for _,k in ipairs({'b','a','select','left','right','up','down','l','r'})do
      if input:wasPressed(k)then key=k;break end
    end
    if input.pressed and key then input.pressed[key]=nil end
    if key=='b' then close()
    elseif key=='a' then save()
    elseif key=='select' then draft=A.clean()
    elseif key then
      local w,h,b=geometry()
      if key=='l' or key=='r' then
        draft.scale=math.max(0.5,math.min(1.25,draft.scale+(key=='l' and -0.05 or 0.05)))
      else
        draft=A.place(draft,w,h,b.x+(key=='left' and -2 or key=='right' and 2 or 0),
          b.y+(key=='up' and -2 or key=='down' and 2 or 0))
      end
    end
  end
  function screen.pointer(action,x,y,pointerId)
    if not valid() then contact=nil;return false end
    pointerId=tostring(pointerId or 'mouse')
    if action=='cancel' then contact=nil;return true end
    local w,h,b=geometry()
    if action=='down' then
      if contact then return true end
      if y>=148 and y<160 then contact={id=pointerId,button=math.floor(x/80)}
      elseif x>=b.x-5 and x<=b.x+b.w+5 and y>=b.y-5 and y<=b.y+b.h+5 then
        contact={id=pointerId,x=x,y=y,b=b,scale=b.scale,
          resize=math.abs(x-(b.x+b.w))<=10 and math.abs(y-math.min(144,b.y+b.h))<=10}
      end
    elseif contact and contact.id==pointerId then
      if action=='up' and contact.button then
        local button=contact.button;contact=nil
        if y>=148 and y<160 and math.floor(x/80)==button then
          if button==0 then save() elseif button==1 then close() elseif button==2 then draft=A.clean() end
        end
      elseif contact.b and (action=='move' or action=='up')then
        if contact.resize then
          local dx,dy=x-contact.x,y-contact.y
          local change=(dx*w+dy*h)/(w*w+h*h)
          draft.scale=math.max(0.5,math.min(1.25,contact.scale+change))
          draft=A.place(draft,w,h,contact.b.x,contact.b.y)
        else draft=A.place(draft,w,h,contact.b.x+x-contact.x,contact.b.y+y-contact.y) end
      end
      if action=='up' then contact=nil end
    end
    return true
  end
  function screen.draw()
    if not valid() then close();return end
    local g=love.graphics
    g.push('all');g.setColor(0.08,0.14,0.18,0.5);g.rectangle('fill',0,0,240,160);g.setColor(1,1,1,1)
    Menu._frlgStartPreview=true
    local ok,err=pcall(Menu.draw)
    Menu._frlgStartPreview=nil
    if not ok then g.pop();error(err,0)end
    local _,_,b=geometry()
    g.setColor(0.05,0.55,0.85,1);g.rectangle('line',b.x+1,b.y+1,b.w-2,b.h-2)
    -- Keep the resize grip above the footer even at the default full height.
    g.rectangle('fill',b.x+b.w-8,math.min(140,b.y+b.h-8),8,8)
    g.setColor(0.04,0.09,0.14,0.96);g.rectangle('fill',0,148,240,12);g.setColor(1,1,1,1)
    local font=require('src.ui.game3.frlg_font')
    local white={small=true,colors=font.COLOR.WHITE}
    Window.printPx('A: SAVE',3,148,white);Window.printPx('B: CANCEL',82,148,white)
    Window.printPx('SELECT: RESET',161,148,white)
    g.setColor(0.04,0.09,0.14,0.96);g.rectangle('fill',0,0,240,12);g.setColor(1,1,1,1)
    Window.printPx(saveFailed and 'SAVE FAILED - RETRY OR CANCEL' or ('MOVE: DRAG/D-PAD  SIZE: CORNER/L/R  '..math.floor(b.scale*100+0.5)..'%'),2,0,white)
    g.pop()
  end
  local function windowPointer(action,x,y,pointerId)
    -- Companion panels own their own viewport and forward native coordinates.
    if Menu._frlgStartEditorOnCompanion and Menu._frlgStartEditorOnCompanion() then return false end
    if not valid() then return false end
    local scale,ox,oy,_,_,sy=Display.fit()
    return screen.pointer(action,(x-ox)/scale,(y-oy)/(sy or scale),pointerId)
  end
  local function bind(game)
    if not game then return end
    release();boundGame=game;patches={}
    local function wrap(key,fn)
      local old=rawget(game,key);local previous=game[key]
      if type(previous)~='function' then return end
      local wrapped=function(...) if fn(...)then return true end;return previous(...)end
      patches[#patches+1]={key=key,old=old,fn=wrapped};game[key]=wrapped
    end
    for key,action in pairs({mousepressed='down',mousemoved='move',mousereleased='up'})do
      if action=='move' then wrap(key,function(_,x,y,dx,dy,touch)if not touch then return windowPointer(action,x,y,'mouse')end end)
      else wrap(key,function(_,x,y,button,touch)if button==1 and not touch then return windowPointer(action,x,y,'mouse')end end)end
    end
    for key,action in pairs({touchpressed='down',touchmoved='move',touchreleased='up'})do
      wrap(key,function(_,finger,x,y)return windowPointer(action,x,y,finger)end)
    end
    for _,key in ipairs({'focus','visible','returnToTitle','quit','_releaseModInput'})do
      wrap(key,function()contact=nil;return false end)
    end
  end
  function E.open()
    draft=A.clean(organizer.appearance());session=Menu._session;contact=nil;saveFailed=nil
    Stack.push(id,screen,{fullscreen=true});bind(Menu._game)
  end
  return E
end
