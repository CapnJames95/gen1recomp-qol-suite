return function(mod, active, Layout)
  local Menu=require('src.ui.game3.start_menu')
  local Stack=require('src.ui.game3.stack')
  local Window=require('src.ui.game3.window')
  local Font=require('src.ui.game3.frlg_font')
  local state, source, game, location, rootCursor, loaded = Layout.clean(), nil, nil, 'root', 1, false
  local projection, readFailed
  local pages={}
  local screen={}
  local screenId='frlg_scrollable_start:organizer'
  local rebuild, home, folderActions, orderPage, destinations
  local function text(label,x,y,width,small)
    label=tostring(label or '')
    if Font.measure(label,{small=small})>width then
      local chars=Font.countChars(label)
      repeat chars=chars-1;label=Font.truncate(label,chars) until chars<=0 or Font.measure(label..'...',{small=small})<=width
      label=label..'...'
    end
    Window.printPx(label,x,y,{maxWidth=width,small=small})
  end
  local function page(title,rows,move)
    pages[#pages+1]={title=title,rows=rows,index=1,move=move}
    Stack.push(screenId,screen,{hideBelow=true,fullscreen=true})
    return pages[#pages]
  end
  local function back()
    table.remove(pages)
    if #pages==0 then Stack.pop(screenId);rebuild() end
  end
  local function notice(title,message)
    page(title,{{label=message},{label='BACK',choose=back}})
  end
  local function save(change,done,quiet)
    if readFailed then if not quiet then notice('STORAGE UNAVAILABLE','Reopen Start to retry.')end;return false end
    local nextState=Layout.clean(state)
    change(nextState)
    local ok,result=pcall(mod.storage.write,mod.storage,game,'menu_layout',nextState)
    if not ok or not result then
      if not quiet then notice('SAVE FAILED','Layout was not changed.')end
      return false
    end
    state=nextState
    rebuild()
    if done then done() end
    return true
  end
  local function nameFolder(id)
    local old
    for _,f in ipairs(state.folders) do if f.id==id then old=f.name end end
    require('src.ui.game3.naming').open({title='FOLDER NAME',template='BOX',maxLen=12,
      seed=old,session=Menu._session,onDone=function(name)
        if not active() then return end
        name=type(name)=='string' and name:match('^%s*(.-)%s*$') or ''
        if name=='' or name==old then return end
        for _,f in ipairs(state.folders) do
          if f.id~=id and f.name:upper()==name:upper() then notice('NAME IN USE','Choose another name.');return end
        end
        save(function(s)
          if id then for _,f in ipairs(s.folders) do if f.id==id then f.name=name end end
          else Layout.create(s,name) end
        end,home)
      end})
  end
  local function refreshOrder(where)
    table.remove(pages)
    orderPage(where)
  end
  destinations=function(node)
    local rows={}
    local function add(id,label)
      rows[#rows+1]={label=label,choose=function()
        save(function(s) Layout.move(s,node.key,id) end,home)
      end}
    end
    add('root','MAIN MENU')
    for _,f in ipairs(state.folders) do add(f.id,f.name) end
    page('MOVE '..node.label,rows)
  end
  orderPage=function(where)
    local nodes=Layout.nodes(state,source,where)
    local rows={{label='SORT A-Z',choose=function()
      save(function(s)
        local ordered=Layout.nodes(s,source,where)
        table.sort(ordered,function(a,b)
          if a.label:upper()==b.label:upper() then return a.key<b.key end
          return a.label:upper()<b.label:upper()
        end)
        Layout.order(s,where,ordered)
      end,function() refreshOrder(where) end)
    end}}
    for _,node in ipairs(nodes) do
      rows[#rows+1]={label=(node.folder and '+ ' or '')..node.label,node=node}
    end
    local p=page(where=='root' and 'MAIN MENU ORDER' or 'FOLDER ORDER',rows,function(delta,p)
      local target=p.index+delta
      -- SORT A-Z is a command, not a movable entry. Stop at either end.
      if target<2 or target>#p.rows then return end
      p.rows[p.index],p.rows[target]=p.rows[target],p.rows[p.index]
      p.index=target
    end)
    p.cancelMove=function()
      local original=p.grab
      refreshOrder(where)
      pages[#pages].index=original
    end
    p.place=function()
      local index=p.index
      save(function(s)
        local ordered={}
        for _,row in ipairs(p.rows) do if row.node then ordered[#ordered+1]=row.node end end
        Layout.order(s,where,ordered)
      end,function() refreshOrder(where);pages[#pages].index=index end)
    end
  end
  folderActions=function(id)
    page('EDIT FOLDER',{
      {label='RENAME',choose=function() nameFolder(id) end},
      {label='ORDER CONTENTS',choose=function() orderPage(id) end},
      {label='DELETE FOLDER',choose=function()
        page('RETURN CONTENTS TO MAIN?',{
          {label='NO',choose=back},
          {label='YES',choose=function() save(function(s) Layout.delete(s,id) end,home) end}})
      end}})
  end
  home=function()
    pages={}
    page('ORGANIZE MENU',{
      {label='NEW FOLDER',choose=function() nameFolder() end},
      {label='ORDER MAIN MENU',choose=function() orderPage('root') end},
      {label='MOVE MOD ENTRIES',choose=function()
        local rows={}
        for _,node in ipairs(Layout.entries(source)) do
          if node.movable then rows[#rows+1]={label=node.label,choose=function() destinations(node) end} end
        end
        if #rows==0 then notice('MOVE MOD ENTRIES','No mod shortcuts available.') else page('CHOOSE MOD ENTRY',rows) end
      end},
      {label='EDIT FOLDERS',choose=function()
        local rows={}
        for _,f in ipairs(state.folders) do rows[#rows+1]={label=f.name,choose=function() folderActions(f.id) end} end
        if #rows==0 then notice('EDIT FOLDERS','Create a folder first.') else page('CHOOSE FOLDER',rows) end
      end},
      {label='RESET LAYOUT',choose=function()
        page('RESET ORDER AND FOLDERS?',{{label='NO',choose=back},{label='YES',choose=function()
          save(function(s) s.folders={};s.parents={};s.orders={} end,home)
        end}})
      end},
      {label='DONE',choose=back}})
  end
  rebuild=function(focus)
    if not source then return end
    if not active() then Menu.ENTRIES=source;Menu.cursor=math.min(Menu.cursor,#source);return end
    local exists=location=='root'
    for _,f in ipairs(state.folders) do if f.id==location then exists=true end end
    if not exists then location='root' end
    local entries={}
    if location~='root' then
      entries[1]={id='frlg_start_back',label='BACK TO MAIN',onSelect=function()
        location='root';rebuild();Menu.cursor=math.min(rootCursor,#Menu.ENTRIES)
      end}
    end
    for _,node in ipairs(Layout.nodes(state,source,location)) do
      if node.folder then
        entries[#entries+1]={id=node.key,label='+ '..node.label,onSelect=function()
          rootCursor=Menu.cursor;location=node.key;rebuild();Menu.cursor=1
        end}
      else entries[#entries+1]=node.entry end
    end
    entries[#entries+1]={id='frlg_start_organize',label='ORGANIZE MENU',onSelect=home}
    Menu.ENTRIES=entries
    projection=entries
    Menu.cursor=math.max(1,math.min(Menu.cursor,#entries))
    if focus then for i,e in ipairs(entries) do if e==focus then Menu.cursor=i end end end
  end
  function screen.handleInput(input)
    if not active() or not Menu.open then pages={};Stack.pop(screenId);rebuild();return end
    local p=pages[#pages]
    if not p then return end
    if input:wasPressed('b') then
      if input.pressed then input.pressed.b=nil end
      if p.grab then p.cancelMove() else back() end
    elseif input:wasPressed('start') then pages={};Stack.pop(screenId);rebuild()
    elseif input:wasPressed('up') then
      if p.grab then p.move(-1,p) else p.index=(p.index-2)%#p.rows+1 end
    elseif input:wasPressed('down') then
      if p.grab then p.move(1,p) else p.index=p.index%#p.rows+1 end
    elseif input:wasPressed('a') then
      local row=p.rows[p.index]
      if p.grab then p.place()
      elseif p.move and row.node then p.grab=p.index
      elseif row.choose then row.choose() end
    end
  end
  function screen.draw()
    local p=pages[#pages]
    if not p then return end
    local g=love.graphics
    g.push('all');g.setColor(0.94,0.94,0.88,1);g.rectangle('fill',0,0,240,160);g.setColor(1,1,1,1)
    text(p.grab and ('MOVING: '..p.rows[p.index].label) or p.title,8,4,224)
    Window.stdFrame(Window.template(1,4,28,13))
    local first=math.max(1,p.index-6)
    for i=first,math.min(#p.rows,first+6) do
      local y=32+(i-first)*15
      if i==p.index then Window.cursorPx(9,y) end
      text(p.rows[i].label,20,y,208)
    end
    local help=p.grab and 'Up/Down: move  A: place  B: cancel'
      or (p.move and 'Up/Down: choose  A: pick up  B: back' or 'A: choose  B: back  Start: done')
    text(help,8,146,224,true)
    g.pop()
  end
  local show=Menu.show
  Menu.show=function(...)
    show(...)
    if not active() then return end
    source=nil;location='root';pages={};Stack.pop(screenId)
    -- Keep native Safari/link/Union Room menus unchanged.
    local normal=false
    for _,e in ipairs(Menu.ENTRIES) do if e.id=='save' then normal=true end end
    if not normal then return end
    game=Menu._game or (Menu._session and Menu._session.game)
    local ok,data,code=pcall(mod.storage.read,mod.storage,game,'menu_layout')
    readFailed=not ok or (data==nil and code~=nil and code~='not_found')
    state=Layout.clean(ok and data or nil);loaded=true
    source=Menu.ENTRIES
    local focus=source[Menu.cursor]
    rebuild(focus)
  end
  local cancel=Menu.cancel
  Menu.cancel=function(...)
    if active() and source and location~='root' and not Menu._confirmExit then
      location='root';rebuild();Menu.cursor=math.min(rootCursor,#Menu.ENTRIES);return
    end
    return cancel(...)
  end
  -- Draw/confirm guard supports turning the option off while a menu is open.
  local function sync()
    if loaded and source and Menu.ENTRIES==projection and not active() then
      Menu.ENTRIES=source;Menu.cursor=math.max(1,math.min(Menu.cursor,#source));source=nil
      pages={};Stack.pop(screenId)
    end
  end
  local confirm=Menu.confirm
  Menu.confirm=function(...) sync();return confirm(...) end
  return {sync=sync,appearance=function()return state.appearance end,
    saveAppearance=function(value)return save(function(s)s.appearance=value end,nil,true)end}
end
