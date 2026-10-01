-- One paged native menu; every feature retains its original option schema.
return function(mod, active, Shortcuts)
  local Stack = require('src.ui.game3.stack')
  local Window = require('src.ui.game3.window')
  local Start = require('src.ui.game3.start_menu')
  local Support = assert(load(mod:read('components/frlg_qol_auto_surf/support.lua')))()
  local ui = Support.new(mod)
  local id = 'frlg_qol_suite:menu'
  local screen, game, pages = {}, nil, {}
  -- Match the companion's existing paged-row touch protocol without copying
  -- cursor state. A press held across a page change gets a different token.
  setmetatable(screen, {
    __index=function(_,key)
      local page=pages[#pages]
      if key=='rows' or key=='cursor' then return page and page[key] end
      if key=='mode' then return page and page.title end
      if key=='qolSuiteRoot' then return page and page.features or false end
    end,
    __newindex=function(t,key,value)
      if key=='cursor' and pages[#pages] then pages[#pages].cursor=value
      else rawset(t,key,value) end
    end,
  })
  screen.qolSuite=true
  local function close() Stack.pop(id); pages={} end
  local function back()
    if #pages > 1 then table.remove(pages) else close() end
  end
  local function valueLabel(row, value)
    if row.type == 'toggle' then return value and 'ON' or 'OFF' end
    for _, choice in ipairs(row.choices or {}) do if choice[2] == value then return choice[1] end end
    return tostring(value or '')
  end
  local function options(feature)
    local rows = {}
    if feature.where then
      for _,line in ipairs(feature.where) do rows[#rows+1]={label=line,action=function()end} end
    end
    local allowed
    if feature.keys then allowed={};for _,key in ipairs(feature.keys) do allowed[key]=true end end
    for _, option in ipairs(mod.exports.schema(feature.id)) do
      local row = option
      if not allowed or allowed[row.key] then
      rows[#rows+1] = {label=function()
        local label=row.label
        if feature.keys and feature.id==mod.id then label=row.key:match('_button$') and 'GAME BUTTON' or row.key:match('_pad$') and 'EXTRA PAD' or 'EXTRA KEY' end
        return (row.key == 'enabled' and 'ENABLED' or label)..': '..valueLabel(row, mod.exports.value(feature.id,row.key))
      end, action=function(direction)
        local value = mod.exports.value(feature.id,row.key)
        if row.type == 'toggle' then mod.exports.set(feature.id,row.key,not value)
        elseif row.type == 'choice' then
          local choices, index = row.choices or {}, 1
          for i, choice in ipairs(choices) do if choice[2] == value then index=i end end
          if #choices > 0 then
            index = (index-1+(direction or 1)) % #choices+1
            mod.exports.set(feature.id,row.key,choices[index][2])
          end
        elseif row.type == 'text' then
          local session = game.session
          require('src.ui.game3.naming').open({title=row.label,template='BOX',maxLen=row.maxLen or 7,
            seed=tostring(value or ''),session=session,onDone=function(text)
              if active() and game.session == session and type(text) == 'string' then
                mod.exports.set(feature.id,row.key,text)
              end
            end})
        end
      end}
      end
    end
    rows[#rows+1] = {label='BACK',action=back}
    pages[#pages+1] = {title=feature.label,rows=rows,cursor=1}
  end
  function screen.handleInput(input)
    if not active() then close();return end
    local page=pages[#pages]; if not page then return end
    if input:wasPressed('b') then
      -- A popped layer must not leave its Back edge for the parent HUD.
      if input.pressed then input.pressed.b=nil end
      back();return
    end
    if input:wasPressed('start') then
      local parent=pages[1] and pages[1].hub
      close();if parent and Start.open then Start.close(true) end;return
    end
    local count=#page.rows
    if input:wasPressed('up') then page.cursor=(page.cursor-2)%count+1
    elseif input:wasPressed('down') then page.cursor=page.cursor%count+1
    elseif input:wasPressed('select') and page.features then
      local row=page.rows[page.cursor]; if row.feature and row.feature.ready then options(row.feature) end
    elseif input:wasPressed('a') then page.rows[page.cursor].action(1)
    elseif input:wasPressed('left') or input:wasPressed('right') then
      local direction=input:wasPressed('left') and -1 or 1
      if page.features or page.list then page.cursor=math.max(1,math.min(count,page.cursor+direction*6))
      else page.rows[page.cursor].action(direction) end
    end
  end
  function screen.draw()
    local page=pages[#pages]; if not page then return end
    ui.chrome(page.title, page.cursor..'/'..#page.rows,
      page.features and 'A: toggle  SELECT: options  B: back' or page.list and 'A: configure  B: back' or 'A/Left/Right: change  B: back')
    ui.frame(1,3,28,13)
    local first=math.floor((page.cursor-1)/6)*6+1
    for index=first,math.min(#page.rows,first+5) do
      local row=page.rows[index];local y=28+(index-first)*16
      if index==page.cursor then
        love.graphics.setColor(0.82,0.91,0.96,1);love.graphics.rectangle('fill',9,y,222,16)
        love.graphics.setColor(1,1,1,1);Window.cursorPx(10,y)
      end
      ui.text(type(row.label)=='function' and row.label() or row.label,19,y,208,true)
    end
  end
  local M={}
  local function openPage(page)
    -- Keep the QOL hub underneath Settings/Shortcuts, including its cursor.
    if Stack.top() and Stack.top().mod==screen and pages[#pages] and pages[#pages].hub then
      pages[#pages+1]=page
    else pages={page} end
    Stack.push(id,screen,{hideBelow=true,fullscreen=true})
  end
  function M.hub(currentGame)
    if not currentGame.session then return false end
    game=currentGame
    local rows={}
    for key,tool in pairs(Start.__frlgQolTools or {}) do
      if tool.active() then
        local selected,toolId=tool,key
        rows[#rows+1]={label=selected.label,action=function()
          if toolId~=mod.id and toolId~=mod.id..':shortcuts' then
            return ui.choose(function() selected.callback(game) end)
          end
          selected.callback(game)
        end}
      end
    end
    table.sort(rows,function(a,b)return a.label<b.label end)
    pages={{title='QOL TOOLS',rows=rows,cursor=1,list=true,hub=true}}
    Stack.push(id,screen,{hideBelow=true,fullscreen=true})
    return true
  end
  function M.show(currentGame)
    if not currentGame.session then return false end
    game=currentGame
    local rows={}
    for _, feature in ipairs(mod.exports.rows()) do
      local f=feature
      rows[#rows+1]={feature=f,label=function()
        return (not f.ready and '[ERROR] ' or mod.exports.value(f.id,'enabled')~=false and '[ON] ' or '[OFF] ')..f.label
      end,action=function()
        if f.ready then mod.exports.set(f.id,'enabled',mod.exports.value(f.id,'enabled')==false)
        else ui.notice(f.error or 'Feature unavailable; check mod errors.') end
      end}
    end
    openPage({title='QOL SETTINGS',rows=rows,cursor=1,features=true})
    return true
  end
  function M.shortcuts(currentGame)
    if not currentGame.session then return false end
    game=currentGame
    local rows={}
    for _,feature in ipairs(Shortcuts.pages()) do
      local f=feature
      rows[#rows+1]={label=f.label,action=function() options(f) end}
    end
    openPage({title='QOL SHORTCUTS',rows=rows,cursor=1,list=true})
    return true
  end
  return M
end
