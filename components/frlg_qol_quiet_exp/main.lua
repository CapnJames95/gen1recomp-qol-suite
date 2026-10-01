return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "bars", label = "INSTANT EXP BARS", type = "toggle", default = true },
  })
  local api = Support.new(mod)
  local Sequence = require("src.core.game3.battle.exp_seq")
  local Text = require("src.core.game3.battle.battle_text")
  local Anim = require("src.core.game3.battle.anim")
  local captured
  local function allowed()
    local state = require("src.core.game3.battle.ui")._st
    return not state or not (state.link or state.spectate or state.pokedude or state.oldManTutorial)
  end
  api.wrap(Text, "get", function(previous, key, ...)
    local text = previous(key, ...)
    if captured and key == "STRINGID_PKMNGAINEDEXP" and text ~= nil then
      captured[text] = (captured[text] or 0) + 1
    end
    return text
  end)
  api.wrap(Sequence, "begin", function(previous, awards, pushMsg, thenMsgs, options)
    if not allowed() then return previous(awards, pushMsg, thenMsgs, options) end
    local outer, messages = captured, {}
    captured = messages
    local ok, started = pcall(previous, awards, pushMsg, thenMsgs, options)
    captured = outer
    if not ok then error(started, 0) end
    if not started or not Sequence._steps then return started end
    local steps = Sequence._steps
    local tail = #(thenMsgs or (options and options.thenMsgs) or {})
    local kept = {}
    for index, step in ipairs(steps) do
      local text = step.data and step.data.text
      if index <= #steps - tail and step.kind == "msg" and text ~= nil and (messages[text] or 0) > 0 then
        messages[text] = messages[text] - 1
      else
        kept[#kept + 1] = step
      end
    end
    Sequence._steps = kept
    if #kept == 0 then Sequence.reset() return false end
    return started
  end)
  api.wrap(Anim, "tweenExp", function(previous, side, fromRatio, toRatio, options)
    local step = Sequence._steps and Sequence._steps[Sequence._i]
    if allowed() and mod.options:get("bars") and step and step.kind == "exp" then
      options = api.copy(options)
      options.instant = true
    end
    return previous(side, fromRatio, toRatio, options)
  end)
end
