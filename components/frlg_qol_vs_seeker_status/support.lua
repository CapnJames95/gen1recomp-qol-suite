local Runtime = require("src.mods.Runtime")
local GameVersion = require("src.core.GameVersion")
local Support = {}

function Support.new(mod)
  local owner = Runtime.events
  local api = {}
  function api.active()
    local version = GameVersion.get()
    return Runtime.events == owner and (version == "firered" or version == "leafgreen" or version == "emerald")
      and mod.options:get("enabled") ~= false
  end
  function api.wrap(target, name, handler)
    assert(type(target[name]) == "function", "Unsupported FRLG build: missing " .. name)
    target.__frlgQol = target.__frlgQol or {}
    local key = mod.id .. ":" .. name
    local record = target.__frlgQol[key]
    if not record then
      record = { previous = target[name] }
      target.__frlgQol[key] = record
      target[name] = function(...)
        if record.active() then return record.handler(record.previous, ...) end
        return record.previous(...)
      end
    end
    record.active, record.handler = api.active, handler
  end
  function api.session()
    return require("src.core.game3.runtime").getSession()
  end
  function api.copy(value)
    local out = {}
    for key, item in pairs(value or {}) do out[key] = item end
    return out
  end
  function api.partyReady(menu)
    local session = api.session()
    return menu.open and menu.mode == "list" and not menu._hpAnim and not menu._pokedude
      and session and menu._party == session.party and session.party[menu.cursor]
      and not require("src.core.game3.pokemon").isEgg(session.party[menu.cursor])
      and not require("src.core.game3.battle").isActive()
  end
  function api.text(value, x, y, width, small, colors)
    local Font = require("src.ui.game3.frlg_font")
    value = tostring(value or "")
    if Font.measure(value, { small = small }) > width then
      while #value > 0 and Font.measure(value .. "...", { small = small }) > width do
        value = value:sub(1, -2)
      end
      value = value .. "..."
    end
    require("src.ui.game3.window").printPx(value, x, y,
      { maxWidth = width, small = small, colors = colors })
  end
  function api.frame(x, y, width, height)
    local Window = require("src.ui.game3.window")
    local session = api.session()
    Window.userFrame(Window.template(x, y, width, height),
      session and session.options and session.options.frameType or 0)
  end
  function api.chrome(title, marker, help)
    local Font = require("src.ui.game3.frlg_font")
    love.graphics.setColor(0.78, 0.88, 0.9, 1)
    love.graphics.rectangle("fill", 0, 0, 240, 160)
    love.graphics.setColor(0.73, 0.84, 0.87, 1)
    for offset = 18, 135, 4 do love.graphics.rectangle("fill", 0, offset, 240, 1) end
    love.graphics.setColor(0, 123 / 255, 197 / 255, 1)
    love.graphics.rectangle("fill", 0, 0, 240, 16)
    love.graphics.setColor(1, 1, 1, 1)
    api.text(title, 8, 0, 174, false, Font.COLOR.WHITE)
    api.text(marker or (GameVersion.get() == "emerald" and "EM" or GameVersion.get() == "leafgreen" and "LG" or "FR"),
      202, 0, 30, true, Font.COLOR.WHITE)
    api.frame(1, 17, 28, 2)
    api.text(help or "A: choose  B: back  Left/Right: page", 12, 136, 216, true)
  end
  -- Suspend the QoL chain only while dispatching an action. Native field
  -- actions must see an idle UI; a newly opened page keeps the original chain.
  function api.choose(callback, replace)
    local Stack = require("src.ui.game3.stack")
    local Start = require("src.ui.game3.start_menu")
    local parents = {}
    while Stack.top() do
      local layer = Stack.top()
      if layer.id ~= "start" and not layer.mod.qolPage and not layer.mod.qolSuite then break end
      table.insert(parents, 1, table.remove(Stack._layers))
    end
    local startOpen = Start.open
    local suspendedStart = false
    for _, layer in ipairs(parents) do
      if layer.id == "start" then suspendedStart = true; Start.open = false end
    end
    local base = Stack.depth()
    local ok, err = pcall(callback)
    if not ok or Stack.depth() > base then
      if ok and replace then table.remove(parents) end
      for i, layer in ipairs(parents) do table.insert(Stack._layers, base + i, layer) end
      if suspendedStart then Start.open = startOpen end
    elseif suspendedStart then
      Start.close(true)
    end
    if not ok then error(err, 0) end
  end
  function api.menu(title, rows, done)
    local Stack = require("src.ui.game3.stack")
    local Window = require("src.ui.game3.window")
    local id = mod.id .. ":menu"
    local screen = { cursor = 1, rows = rows, qolPage = true, mode = title }
    function screen.close()
      Stack.pop(id)
      if done then done() end
    end
    function screen.back()
      screen.close()
      local parent = Stack.top() and Stack.top().mod
      if parent and parent.qolPage and parent.refresh then
        local cursor = parent.cursor
        api.choose(parent.refresh, true)
        if Stack.top() then Stack.top().mod.cursor = math.min(cursor, #Stack.top().mod.rows) end
      end
    end
    function screen.handleInput(input)
      if input:wasPressed("b") then
        if input.pressed then input.pressed.b = nil end
        screen.back() return
      end
      local count = #screen.rows
      if count == 0 then return end
      if input:wasPressed("up") then screen.cursor = (screen.cursor - 2) % count + 1
      elseif input:wasPressed("down") then screen.cursor = screen.cursor % count + 1
      elseif input:wasPressed("left") then screen.cursor = math.max(1, screen.cursor - 6)
      elseif input:wasPressed("right") then screen.cursor = math.min(count, screen.cursor + 6)
      elseif input:wasPressed("a") then
        local row = screen.rows[screen.cursor]
        if input.pressed then input.pressed.a = nil end
        if row.back then screen.back()
        elseif row.choose then api.choose(row.choose, row.replace) end
      end
    end
    function screen.draw()
      api.chrome(title, #screen.rows > 6 and (screen.cursor .. "/" .. #screen.rows) or nil)
      api.frame(1, 3, 28, 13)
      local first = math.floor((screen.cursor - 1) / 6) * 6 + 1
      for index = first, math.min(#screen.rows, first + 5) do
        local row = screen.rows[index]
        local label = type(row.label) == "function" and row.label() or row.label
        local ypos = 28 + (index - first) * 16
        if index == screen.cursor then
          love.graphics.setColor(0.82, 0.91, 0.96, 1)
          love.graphics.rectangle("fill", 9, ypos, 222, 16)
          love.graphics.setColor(1, 1, 1, 1)
          Window.cursorPx(10, ypos)
        end
        api.text(label, 19, ypos, 208, true)
      end
    end
    -- Multiple pages from one component share its public touch-layer ID.
    -- Pop removes the topmost match, preserving earlier pages and cursors.
    Stack._layers[#Stack._layers + 1] = { id = id, mod = screen, hideBelow = true, fullscreen = true }
    return screen
  end
  function api.lines(value, width)
    local Font = require("src.ui.game3.frlg_font")
    local lines, line = {}, ""
    for word in tostring(value or ""):gmatch("%S+") do
      local trial = line == "" and word or line .. " " .. word
      if line ~= "" and Font.measure(trial, { small = true }) > (width or 208) then
        lines[#lines + 1], line = line, word
      else line = trial end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
  end
  function api.notice(text)
    local rows = {}
    for _, line in ipairs(api.lines(text)) do rows[#rows + 1] = { label = line } end
    rows[#rows + 1] = { label = "OK", back = true, choose = function() end }
    return api.menu("INFORMATION", rows)
  end
  function api.startItem(label, callback)
    local StartMenu = require("src.ui.game3.start_menu")
    api.wrap(StartMenu, "draw", function(previous, ...)
      if (StartMenu._frlgStartRenderer and StartMenu._frlgStartRenderer())
          or not StartMenu.open or #StartMenu.ENTRIES <= 9 or StartMenu._confirmExit or StartMenu._safariStats then
        return previous(...)
      end
      local Window = require("src.ui.game3.window")
      api.chrome("START MENU", StartMenu.cursor .. "/" .. #StartMenu.ENTRIES,
        "Up/Down: choose  A: open  B: close")
      api.frame(1, 3, 28, 13)
      local first = math.floor((StartMenu.cursor - 1) / 6) * 6 + 1
      for index = first, math.min(#StartMenu.ENTRIES, first + 5) do
        local ypos = 28 + (index - first) * 16
        if index == StartMenu.cursor then
          love.graphics.setColor(0.82, 0.91, 0.96, 1)
          love.graphics.rectangle("fill", 9, ypos, 222, 16)
          love.graphics.setColor(1, 1, 1, 1)
          Window.cursorPx(10, ypos)
        end
        api.text(StartMenu.ENTRIES[index].label, 19, ypos, 208, true)
      end
    end)
    StartMenu.__frlgQolTools = StartMenu.__frlgQolTools or {}
    StartMenu.__frlgQolTools[mod.id] = { label = label, callback = callback, active = api.active }
    mod.hooks:wrap("ui.start_menu.items", function(nextHook, game, items)
      local out = nextHook(game, items)
      if api.active() and type(out) == "table" then
        for _, row in ipairs(out) do if row.id == "frlg_qol_tools" then return out end end
        out[#out + 1] = { id = "frlg_qol_tools", label = "QOL", onSelect = function()
          local rows = {}
          for _, tool in pairs(StartMenu.__frlgQolTools) do
            if tool.active() then
              local selected = tool
              rows[#rows + 1] = { label = selected.label,
                choose = function() selected.callback(game) end }
            end
          end
          table.sort(rows, function(left, right) return left.label < right.label end)
          api.menu("QOL TOOLS", rows)
        end }
      end
      return out
    end)
  end
  return api
end

return Support
