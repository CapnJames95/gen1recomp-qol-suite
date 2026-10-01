local View = {}
local Window = require("src.ui.game3.window")
local Font = require("src.ui.game3.frlg_font")

local function text(value, left, top, width, small, colors)
  value = tostring(value or "")
  if Font.measure(value, { small = small }) > width then
    while #value > 0 and Font.measure(value .. "...", { small = small }) > width do value = value:sub(1, -2) end
    value = value .. "..."
  end
  Window.printPx(value, left, top, { maxWidth = width, small = small, colors = colors })
end

function View.wrap(value, width)
  local rows, line = {}, ""
  for word in tostring(value):gmatch("%S+") do
    local trial = line == "" and word or line .. " " .. word
    if Font.measure(trial, { small = true }) > width and line ~= "" then rows[#rows + 1], line = line, word
    else line = trial end
  end
  if line ~= "" then rows[#rows + 1] = line end
  return rows
end

function View.draw(screen)
  local page = screen.pages[#screen.pages]
  local function frame(left, top, width, height)
    Window.userFrame(Window.template(left, top, width, height), screen.frameType)
  end
  love.graphics.setColor(0.78, 0.88, 0.9, 1)
  love.graphics.rectangle("fill", 0, 0, 240, 160)
  love.graphics.setColor(0.73, 0.84, 0.87, 1)
  for offset = 18, 135, 4 do love.graphics.rectangle("fill", 0, offset, 240, 1) end
  love.graphics.setColor(0, 123 / 255, 197 / 255, 1)
  love.graphics.rectangle("fill", 0, 0, 240, 16)
  love.graphics.setColor(1, 1, 1, 1)
  text(page.title, 8, 0, 190, false, Font.COLOR.WHITE)
  text(#page.rows > 6 and (page.cursor .. "/" .. #page.rows) or screen.session.version == "emerald" and "EM" or screen.session.version == "leafgreen" and "LG" or "FR", 202, 0, 31, true, Font.COLOR.WHITE)
  local help = "A: open  B/L: back  START: close"
  frame(1, 3, 28, 13)
  local first = math.max(1, math.min(page.cursor - 5, #page.rows - 5))
  for index = first, math.min(#page.rows, first + 5) do
    local row, top = page.rows[index], 28 + (index - first) * 16
    if index == page.cursor then
      love.graphics.setColor(0.82, 0.91, 0.96, 1)
      love.graphics.rectangle("fill", 9, top, 222, 16)
      love.graphics.setColor(1, 1, 1, 1)
      Window.cursorPx(10, top)
    end
    text(type(row.label) == "function" and row.label() or row.label, 19, top, 208, true)
  end
  local selected = page.rows[page.cursor]
  help = selected and selected.help or help
  frame(1, 17, 28, 2)
  text(help, 12, 136, 216, true)
end

return View
