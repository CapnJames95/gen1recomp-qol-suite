return function(mod)
  local function module(name) return assert(load(assert(mod:read(name..'.lua')),'@capture-assistant/'..name..'.lua'))() end
  mod.options:define({{key='enabled',label='ENABLED',type='toggle',default=true}})
  local E=module('runtime')(mod)
  local Model=module('model')
  local Battle=require('src.core.game3.battle')
  local Ui=require('src.core.game3.battle.ui')
  local Runtime=require('src.core.game3.runtime')
  function E.battleValid(st)
    local s=Runtime.getSession()
    if s and s.version=='emerald' and s.frontier and (s.frontier.challengeStatus or 0)~=0 then return false end
    local top=require('src.ui.game3.stack').top()
    return Battle.isActive() and Ui._st==st and Model.supported(st)
      and Ui._mode=='menu' and not Ui._showing and not Ui._pendingCommand
      and (not top or top.id==mod.id)
  end
  local Screen=module('screen')(Model,module('menu')(module('view')),E)
  local function active() local s=Screen.active;return s and not s.closed and s.battle and s end
  mod.hooks:wrap('input.step',function(next,game,dt)
    local s=Screen.active
    if s and not s.closed then s.update() end
    return next(game,dt)
  end)
  E.start('CAPTURE HELP',function(s) Screen.show(s) end)
  E.helpLease(function()
    local top=require('src.ui.game3.stack').top()
    return active() or E.battleValid(Ui._st) or (top and top.id==mod.id)
  end)
  E.wrap(Ui,'handleInput',function(previous,input)
    if active() then return true end
    if input and input:wasPressed('r') and E.battleValid(Ui._st)
      and not require('src.ui.game3.stack').busy() then
      Screen.show(Runtime.getSession(),Ui._st);return true
    end
    return previous(input)
  end)
  E.wrap(Battle,'update',function(previous,dt,game)
    local s=active()
    if s then
      s.update()
      if not s.closed then s.handleInput(game and game.input) end
      return -- never leak the closing button or advance a turn
    end
    return previous(dt,game)
  end)
  E.wrap(Ui,'draw',function(previous,...)
    local s=active()
    if s then
      s.update()
      if not s.closed then
        if Ui._frlgCapturePresented and Ui._frlgCapturePresented(s) then
          return previous(...) -- companion owns the panel; keep the battle above
        end
        s.draw();return
      end
    end
    return previous(...)
  end)
  mod.exports.show=function(session)
    if E.battleValid(Ui._st) then return Screen.show(session,Ui._st) end
    return Screen.show(session)
  end
end
