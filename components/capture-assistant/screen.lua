return function(Model,Menu,services)
  local Screen={}
  function Screen.show(session,st)
    local ui=Menu.new('capture-assistant',session,function()
      return services.active(session) and (not st or services.battleValid(st))
    end)
    ui.battle=st
    -- Opt in to the companion's capture-panel handoff. Older companions simply
    -- leave this native modal on the main screen.
    ui.captureCompanion=1
    Screen.active=ui
    local snapshot,why
    if st then snapshot,why=Model.snapshot(session,st) end
    local function help()
      ui.info('CAPTURE ASSISTANT HELP',{
        'In a wild single battle, use the battle shortcut at FIGHT / BAG / POKEMON / RUN (R by default; configurable in the QoL Suite). R, START or B at home closes the assistant.',
        'Compare owned balls, inspect possible improvements and read moveset risks. No item is spent and no turn passes.',
        'Percentages estimate one throw using this engine, including current HP, status, terrain, turn and caught history.',
        'Best ball excludes Master Balls. Tied balls are ordered by item ID, not price.',
        'The 1 HP and sleep examples are hypothetical. Check immunity and damage before trying to set them up.',
        'Other catch-rate mods can change outcomes: displayed values remain baseline estimates.',
        'Trainer, Safari, double, linked, spectator, tutorial and ghost battles are excluded.',
        'Up/Down: scroll. Left/Right: skip five. A: choose. B/L: back. START: close.'})
    end
    local function balls()
      local rows={}
      for _,ball in ipairs(snapshot.balls) do
        local selected=ball
        rows[#rows+1]={label=ball.name..' x'..ball.count..' / '..Model.percent(ball.chance),action=function()
          ui.info(selected.name,{
            'Owned: '..selected.count,
            'One throw now: '..Model.percent(selected.chance),
            selected.id==1 and 'Master Ball: guaranteed by baseline rules.' or ('Current ball bonus: '..selected.mult..'x'),
            'At 1 HP, same status: '..Model.percent(selected.low),
            'At 1 HP, asleep: '..Model.percent(selected.sleep),
            'Hypothetical setup; no turns, damage, immunity or escape forecast.',
            snapshot.modified and 'Catch-rate mod active: baseline only.' or 'Estimate from native catch rules; no RNG consumed.',
          })
        end}
      end
      if #rows==0 then rows[1]={label='No usable balls in your Bag.'} end
      rows[#rows+1]={label='Back',action=ui.back};ui.push('OWNED BALLS / ESTIMATE',rows)
    end
    if snapshot then
      ui.push('CAPTURE ASSISTANT',{
        {label=snapshot.name..' / HP '..snapshot.hp..'/'..snapshot.maxHp,action=function() ui.info('CURRENT ENCOUNTER',{
          snapshot.name,'HP: '..snapshot.hp..'/'..snapshot.maxHp,'Status: '..tostring(snapshot.status),
          'Battle turn: '..snapshot.turn,'Values are a snapshot at the command menu.'}) end},
        {label=snapshot.best and ('Best: '..snapshot.best.name..' '..Model.percent(snapshot.best.chance)) or 'Best: no ordinary balls',action=balls},
        {label='Compare owned balls',action=balls},
        {label='Capture risks / moveset',action=function() ui.info('CAPTURE RISKS',snapshot.risks) end},
        {label=snapshot.modified and 'Catch mod active: baseline only' or 'Help / calculation details',action=help},
        {label='Return to battle',action=ui.close},
      })
    else
      ui.push('CAPTURE ASSISTANT',{
        {label='How to use in battle',action=help},
        {label=why and 'Encounter unavailable' or 'Open at wild battle commands',action=function() ui.info('BATTLE SHORTCUT',{why or 'Use the battle shortcut at the main wild battle command menu: R by default, or your QoL Suite shortcut.'}) end},
        {label='Close',action=ui.close},
      })
    end
    local input=ui.handleInput
    function ui.handleInput(keys)
      if st and keys and keys:wasPressed('r') then ui.close();return end
      input(keys)
    end
    return ui
  end
  return Screen
end
