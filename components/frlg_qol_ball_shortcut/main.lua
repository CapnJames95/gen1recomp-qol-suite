return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  local api = Support.new(mod)
  local Ui = require("src.core.game3.battle.ui")
  local Bag = require("src.core.game3.bag")
  local Items = require("src.core.game3.items_data")
  local Stack = require("src.ui.game3.stack")
  local Help = require("src.ui.game3.help_system")
  local Window = require("src.ui.game3.window")
  local balls = { 4, 3, 2, 6, 7, 8, 9, 10, 11, 12 }
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "ball", label = "DEFAULT BALL", type = "choice", default = "POKE_BALL",
      choices = { { "POKE BALL", "POKE_BALL" }, { "GREAT BALL", "GREAT_BALL" },
        { "ULTRA BALL", "ULTRA_BALL" } } },
    { key = "key", label = "KEYBOARD HOTKEY", type = "choice", default = "f7",
      choices = { { "F7", "f7" }, { "F8", "f8" }, { "F9", "f9" }, { "C", "c" },
        { "V", "v" }, { "B", "b" }, { "N", "n" }, { "OFF", "off" } } },
    { key = "pad", label = "CONTROLLER BUTTON", type = "choice", default = "y",
      choices = { { "R3 / RIGHT STICK", "rightstick" }, { "L3 / LEFT STICK", "leftstick" },
        { "RIGHT SHOULDER", "rightshoulder" }, { "LEFT SHOULDER", "leftshoulder" },
        { "X / WEST", "x" }, { "Y / NORTH", "y" }, { "BACK / SHARE", "back" }, { "OFF", "off" } } },
    { key = "select", label = "ALSO USE SELECT", type = "toggle", default = true },
  })
  local modal, chosen, chosenSession, configured, drawModal, handle
  local heldKeys, heldPads = {}, {}
  local function ready()
    local state, session = Ui._st, api.session()
    return api.active() and Ui._mode == "menu" and not Ui._headless and not Ui.isShowing()
      and not Ui._pendingCommand and state and state.wild
      and not state.double and not state.safari and not state.link and not state.spectate
      and not state.oldManTutorial and not state.pokedude and not state.ghostBattle
      and session and session.bag and Stack.depth() == 0 and not Help.isOpen()
  end
  local function valid()
    if modal and (not ready() or modal.state ~= Ui._st or modal.session ~= api.session()) then modal = nil end
    return modal ~= nil
  end
  local function selected()
    local session, setting = api.session(), mod.options:get("ball")
    if session ~= chosenSession or setting ~= configured then
      chosenSession, configured = session, setting
      chosen = Items.toNumericId(setting) or 4
    end
    return chosen
  end
  local function show(title, rows, picker)
    modal = { title = title, rows = rows, cursor = 1, picker = picker,
      session = api.session(), state = Ui._st }
    local screen = modal
    screen.draw = function() if valid() and modal == screen then drawModal() end end
    screen.handleInput = function(input) if valid() and modal == screen then handle(input) end end
  end
  local showActions, showBalls
  local function throwBall()
    if not valid() then return end
    local item = selected()
    if Bag.get(modal.session.bag, item) < 1 then showActions() return end
    local allowed = false
    for _, id in ipairs(balls) do if item == id then allowed = true break end end
    if not allowed then return end
    Ui._pendingCommand = { kind = "bag", user = "player", itemId = item }
    Ui._mode, modal = "none", nil
  end
  showActions = function()
    local item = selected()
    local quantity = Bag.get(api.session().bag, item)
    show("BATTLE BALLS", {
      { label = "THROW " .. Items.displayName(item) .. " x" .. quantity, choose = throwBall },
      { label = "SELECT BALL", choose = function() showBalls() end },
      { label = "CANCEL", choose = function() modal = nil end },
    })
    if quantity < 1 then modal.cursor = 2 end
  end
  showBalls = function()
    local rows = {}
    for _, id in ipairs(balls) do
      local quantity = Bag.get(api.session().bag, id)
      if quantity > 0 then
        local item = id
        rows[#rows + 1] = { label = Items.displayName(id) .. " x" .. quantity,
          choose = function() chosen = item showActions() end }
      end
    end
    if #rows == 0 then rows[1] = { label = "No usable Balls in Bag" } end
    rows[#rows + 1] = { label = "BACK", choose = showActions }
    show("SELECT BALL", rows, true)
  end
  local function open(picker)
    if not ready() then return false end
    if not valid() then if picker then showBalls() else showActions() end end
    return true
  end
  mod.exports.battleBallHint = function()
    if not ready() or valid() then return nil end
    local pad, key = mod.options:get("pad"), mod.options:get("key")
    local labels = {rightstick="R3",leftstick="L3",rightshoulder="RB",
      leftshoulder="LB",back="BACK",x="X",y="Y"}
    local binding = pad ~= "off" and labels[pad] or nil
    if not binding and key and key ~= "off" then binding = key:upper() end
    if not binding and mod.options:get("select") then binding = "SELECT" end
    return binding and (binding .. " BALLS") or nil
  end
  handle = function(input)
    if input:wasPressed("b") then
      if modal.picker then showActions() else modal = nil end
      return
    end
    local count = #modal.rows
    if input:wasPressed("up") then modal.cursor = (modal.cursor - 2) % count + 1
    elseif input:wasPressed("down") then modal.cursor = modal.cursor % count + 1
    elseif input:wasPressed("left") then modal.cursor = math.max(1, modal.cursor - 6)
    elseif input:wasPressed("right") then modal.cursor = math.min(count, modal.cursor + 6)
    elseif input:wasPressed("a") then
      local row = modal.rows[modal.cursor]
      if row.choose then row.choose() end
    end
  end
  api.wrap(Ui, "handleInput", function(previous, input)
    if valid() then handle(input) return true end
    if input and mod.options:get("select") and input:wasPressed("select") and open() then return true end
    return previous(input)
  end)
  Ui._frlgQolBallModal = function() if valid() then return modal end end
  drawModal = function()
    api.chrome(modal.title, #modal.rows > 6 and (modal.cursor .. "/" .. #modal.rows) or nil)
    api.frame(1, 3, 28, 13)
    local first = math.floor((modal.cursor - 1) / 6) * 6 + 1
    for index = first, math.min(#modal.rows, first + 5) do
      local ypos = 28 + (index - first) * 16
      if index == modal.cursor then
        love.graphics.setColor(0.82, 0.91, 0.96, 1)
        love.graphics.rectangle("fill", 9, ypos, 222, 16)
        love.graphics.setColor(1, 1, 1, 1)
        Window.cursorPx(10, ypos)
      end
      api.text(modal.rows[index].label, 19, ypos, 208, true)
    end
  end
  api.wrap(Ui, "draw", function(previous, ...)
    if not valid() or (Ui._frlgQolBallPresented and Ui._frlgQolBallPresented()) then return previous(...) end
    drawModal()
  end)
  mod.hooks:wrap("input.key", function(nextHook, game, event)
    if event.phase == "released" then
      heldKeys[event.key] = nil
    elseif event.phase == "pressed" and api.active() then
      if heldKeys[event.key] then return true end
      if event.key == mod.options:get("key") and game.phase == "field"
          and game.session == api.session() and open(true) then
        heldKeys[event.key] = true
        return true
      end
    end
    return nextHook(game, event)
  end)
  mod.hooks:wrap("input.gamepad", function(nextHook, game, event)
    local token = tostring(event.joystick) .. ":" .. tostring(event.button)
    if event.phase == "released" then
      heldPads[token] = nil
    elseif event.phase == "pressed" and api.active() then
      if heldPads[token] then return true end
      if event.button == mod.options:get("pad") and game.phase == "field"
          and game.session == api.session() and open(true) then
        heldPads[token] = true
        return true
      end
    end
    return nextHook(game, event)
  end)
  mod.events:on("battle.started", function() modal = nil end)
  mod.events:on("battle.ended", function() modal = nil end)
  api.wrap(require("src.core.Game3"), "focus", function(previous, game, focused, ...)
    if not focused then modal, heldKeys, heldPads = nil, {}, {} end
    return previous(game, focused, ...)
  end)
end
