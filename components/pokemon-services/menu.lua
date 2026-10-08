-- Collection-style native FRLG menu. Each package carries its own copy.
return function(View)
  local Menu = {}
  local Stack = require('src.ui.game3.stack')
  function Menu.new(id, session, valid, detached)
    local ui = {session=session, pages={}, frameType=session.options and session.options.frameType or 0}
    function ui.close()
      if not detached then Stack.pop(id) end
      ui.closed = true
    end
    function ui.push(title, rows)
      if require('src.core.game3.profile').forSession(session).family=='rse' then
        title=title:gsub('FOUR ISLAND','ROUTE 117')
        local filtered={}
        for _,row in ipairs(rows) do
          if not tostring(row.label):find('Route 5') and not tostring(row.label):find('ROUTE 5') then
            row.label=tostring(row.label):gsub('Four Island','Route 117'):gsub('FOUR ISLAND','ROUTE 117'):gsub('FR/LG has no Everstone nature or shiny%-parent bonus%.',session.version=='emerald' and 'Emerald supports Everstone nature inheritance.' or 'Ruby/Sapphire have no Everstone nature inheritance.'):gsub('Celadon','Lilycove')
            filtered[#filtered+1]=row
          end
        end
        rows=filtered
      end
      if #rows == 0 then rows = {{label='Nothing to show.'}} end
      ui.pages[#ui.pages+1] = {title=title, rows=rows, cursor=1}
    end
    function ui.back()
      if #ui.pages > 1 then table.remove(ui.pages) else ui.close() end
    end
    function ui.info(title, lines)
      local rows = {}
      for _, line in ipairs(lines) do
        for _, part in ipairs(View.wrap(line, 204)) do rows[#rows+1] = {label=part} end
      end
      rows[#rows+1] = {label='Back', action=ui.back}
      ui.push(title, rows)
    end
    function ui.handleInput(input)
      if ui.closed then return end
      if not valid() then ui.close(); return end
      if not input then return end
      if input:wasPressed('start') then ui.close(); return end
      if input:wasPressed('b') or input:wasPressed('l') then
        if input.pressed then input.pressed.b=nil;input.pressed.l=nil end
        ui.back(); return
      end
      local page = ui.pages[#ui.pages]
      local delta = input:wasPressed('up') and -1 or input:wasPressed('down') and 1
        or input:wasPressed('left') and -5 or input:wasPressed('right') and 5 or 0
      page.cursor = (page.cursor-1+delta)%#page.rows+1
      if input:wasPressed('a') and page.rows[page.cursor].action then page.rows[page.cursor].action() end
    end
    function ui.update() if not valid() then ui.close() end end
    function ui.draw() if not ui.closed then View.draw(ui) end end
    if not detached then Stack.push(id, ui, {fullscreen=true}) end
    return ui
  end
  return Menu
end
