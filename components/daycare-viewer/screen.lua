return function(Model, View, services)
  local Screen={}
  local Stack=require('src.ui.game3.stack')
  function Screen.show(session)
    local screen={session=session,pages={},frameType=session.options and session.options.frameType or 0}
    Screen.active=screen
    local snapshot=Model.snapshot(session)
    local function push(title,rows,mon)
      if require('src.core.game3.profile').forSession(session).family=='rse' then
        title=title:gsub('FOUR ISLAND','ROUTE 117')
        local filtered={}
        for _,row in ipairs(rows) do
          if not tostring(row.label):find('Route 5') and not tostring(row.label):find('ROUTE 5') then
            row.label=tostring(row.label):gsub('Four Island','Route 117'):gsub('FOUR ISLAND','ROUTE 117'):gsub('FR/LG has no Everstone nature or shiny%-parent bonus%.',session.version=='emerald' and 'Emerald supports Everstone nature inheritance.' or 'Ruby/Sapphire have no Everstone nature or shiny-parent bonus.'):gsub('Celadon','Lilycove')
            filtered[#filtered+1]=row
          end
        end
        rows=filtered
      end
      screen.pages[#screen.pages+1]={title=title,rows=rows,cursor=1,mon=mon}
    end
    local function back()
      if #screen.pages>1 then table.remove(screen.pages) else Stack.pop('daycare-viewer'); Screen.active=nil end
    end
    local function info(title,lines)
      local rows={}
      for _,line in ipairs(lines) do
        if require('src.core.game3.profile').forSession(session).family=='rse' then
          local text={
            ['Pending egg IVs, nature and shininess are generated on collection.']=session.version=='emerald' and 'A pending egg already has its PID, nature and shininess. IVs are generated on collection.' or 'A pending egg stores part of its PID. Final nature, shininess and IVs are generated on collection.',
            ['FR/LG has no Everstone nature or shiny-parent bonus.']=session.version=='emerald' and 'Emerald supports Everstone nature inheritance and Light Ball Volt Tackle. Shiny parents give no shiny bonus.' or 'Ruby/Sapphire have no Everstone nature inheritance, Light Ball Volt Tackle or shiny-parent bonus.',
            ['Route 5 trains one Pokemon. Four Island trains two and can produce eggs.']='Route 117 trains two Pokemon and can produce eggs.',
            ['Manage / teleport: change deposited Pokemon remotely or travel to either Day Care. Collect eggs in person.']='Manage parents remotely or teleport to Route 117. Collect eggs in person.',
            ['Native FR/LG menus pause walking. This is your real Day Care, not Auto Breeder virtual parents.']='Menus pause walking. This is your real Day Care, separate from Auto Breeder virtual parents.',
          }
          line=(text[line] or line):gsub('Four Island','Route 117')
        end
        for _,part in ipairs(View.wrap(line,204)) do rows[#rows+1]={label=part} end
      end
      push(title,rows)
    end
    local home
    local function confirm(title, label, action)
      push(title, {{label='Cancel',action=back},{label=label,action=action}})
    end
    local function perform(action, teleport)
      local ok,message=action()
      if ok and teleport then
        Stack.pop('daycare-viewer'); Screen.active=nil
        local Start=require('src.ui.game3.start_menu')
        if Start.isOpen() then Start.close(true) end
        return
      end
      snapshot=Model.snapshot(session);home()
      info(ok and 'DAY CARE UPDATED' or 'CANNOT CONTINUE',{message or 'The action could not complete.'})
    end
    local function manage(site)
      local Actions=services.actions
      if not Actions then info('UNAVAILABLE',{'Day Care controls are unavailable.'});return end
      local name=site=='four' and 'FOUR ISLAND' or 'ROUTE 5'
      local function deposit()
        local rows={}
        for slot=1,6 do
          local mon=session.party and session.party[slot]
          if mon then
            local index,selected=slot,mon
            rows[#rows+1]={label='Party '..slot..': '..require('src.core.game3.daycare').nickname(mon),action=function()
              confirm('DEPOSIT AT '..name..'?', 'Deposit '..require('src.core.game3.daycare').nickname(selected),function()
                perform(function() return Actions.deposit(session,site,index,selected) end)
              end)
            end}
          end
        end
        rows[#rows+1]={label='Back',action=back};push('CHOOSE PARTY POKEMON',rows)
      end
      local function withdraw()
        local rows={}
        for slot=1,(site=='four' and 2 or 1) do
          local quote=Actions.quote(session,site,slot)
          if quote then
            local index,selected=slot,quote
            rows[#rows+1]={label=require('src.core.game3.daycare').nickname(quote.mon)..' / $'..quote.cost,action=function()
              confirm('WITHDRAW AT '..name..'?', 'Pay $'..selected.cost..': '..require('src.core.game3.daycare').nickname(selected.mon),function()
                perform(function() return Actions.withdraw(session,site,index,selected) end)
              end)
            end}
          end
        end
        if #rows==0 then info(name,{'No Pokemon deposited.'});return end
        rows[#rows+1]={label='Back',action=back};push('CHOOSE WITHDRAWAL',rows)
      end
      push(name..' CONTROLS',{
        {label='Deposit a party Pokemon',action=deposit},
        {label='Withdraw a Pokemon',action=withdraw},
        {label='Teleport to this Day Care',action=function()
          confirm('TELEPORT TO '..name..'?', 'Teleport now',function() perform(function() return Actions.teleport(session,site) end,true) end)
        end},
        {label='How to change parents',action=function() info('CHANGING POKEMON',{
          'Withdraw a Pokemon, then deposit its replacement from your party.',
          'Normal fees, training, moves and mail apply. Keep another usable Pokemon in your party.',
          'Four Island: collect any waiting egg before changing parents.',
          'Teleport goes inside the Day Care. It bypasses travel and ferry access; story flags stay unchanged.',
          'Save normally to keep changes.'}) end},
        {label='Back',action=back},
      })
    end
    local function details(mon,where)
      if not mon then info(where,{'No Pokemon deposited.'}); return end
      local function spreads()
        local lines={'Stat      IV / EV / at withdrawal'}
        local keys={'hp','atk','def','spe','spa','spd'}
        local fields={'maxHp','attack','defense','speed','spAtk','spDef'}
        local labels={'HP','Attack','Defense','Speed','Sp. Atk','Sp. Def'}
        for i,key in ipairs(keys) do
          lines[#lines+1]=labels[i]..': '..tostring((mon.raw.ivs or {})[key] or 0)..' / '..tostring((mon.raw.evs or {})[key] or 0)..' / '..tostring(mon.preview[fields[i]] or '?')
        end
        info('IV / EV / STATS',lines)
      end
      push(where,{
        {label=mon.name,action=function()
          push('POKEMON DETAILS',{
            {label=mon.species..' / '..mon.gender},
            {label=mon.nature..' / '..(mon.shiny and 'Shiny' or 'Not shiny')},
            {label='Ability: '..mon.ability},
            {label='Item: '..mon.item},
            {label='Lv.'..mon.before..' -> '..mon.level..' (+'..mon.gained..')'},
            {label='A: more identity details',action=function() info('IDENTITY',{
              'OT: '..tostring(mon.raw.otName or '?'),'Trainer ID: '..tostring(mon.raw.otId or 0),
              'Friendship: '..tostring(mon.raw.friendship or 0),'Egg groups: '..mon.groups,
              'Stored mail: '..(mon.mail and 'Yes' or 'No')}) end},
          },mon.raw)
        end},
        {label='Training: Lv.'..mon.before..' -> '..mon.level,action=function() info('TRAINING',{
          'Level gained: '..mon.gained,'Withdrawal fee: $'..mon.cost,'Steps deposited: '..mon.steps,
          'EXP at withdrawal: '..mon.exp,mon.nextLevel and ('Steps to next level: '..mon.nextLevel) or 'Maximum level reached.',
          'Day Care does not evolve Pokemon.'}) end},
        {label='Moves / withdrawal preview',action=function()
          local lines={'Stored moves:'}; for i=1,4 do lines[#lines+1]=i..'. '..mon.moves[i] end
          lines[#lines+1]='Moves if withdrawn now:'; for i=1,4 do lines[#lines+1]=i..'. '..mon.afterMoves[i] end
          lines[#lines+1]='New moves can replace the oldest move.'; info('MOVES',lines)
        end},
        {label='IVs / EVs / projected stats',action=spreads},
        {label='Held item: '..mon.item,action=function() info('HELD ITEM',{'Held item: '..mon.item,'Stored mail: '..(mon.mail and 'Yes' or 'No')}) end},
        {label='Back',action=back},
      })
    end
    local function breeding()
      local lines={snapshot.pending and 'EGG READY - collect at Four Island.' or 'No egg waiting.',
        'Compatibility: '..snapshot.compatibility..'% per check',snapshot.reason}
      if snapshot.offspring then lines[#lines+1]='Offspring: '..snapshot.offspring end
      if not snapshot.pending and snapshot.nextCheck then lines[#lines+1]='Next chance in '..snapshot.nextCheck..' steps.' end
      lines[#lines+1]=snapshot.pending and 'Further egg checks wait until collection.' or 'Checks repeat every 256 steps; an egg is not guaranteed.'
      lines[#lines+1]='Pending egg IVs, nature and shininess are generated on collection.'
      lines[#lines+1]='FR/LG has no Everstone nature or shiny-parent bonus.'
      info('BREEDING / EGG',lines)
    end
    home=function()
      screen.pages={}
      push('DAY CARE',{
        {label='Four Island: '..snapshot.count..'/2 parents',action=function() push('FOUR ISLAND',{
          {label=snapshot.pending and 'Egg ready! View breeding' or 'Breeding / egg status',action=breeding},
          {label='Parent 1: '..(snapshot.parents[1] and snapshot.parents[1].name or 'Empty'),action=function() details(snapshot.parents[1],'PARENT 1') end},
          {label='Parent 2: '..(snapshot.parents[2] and snapshot.parents[2].name or 'Empty'),action=function() details(snapshot.parents[2],'PARENT 2') end},
          {label='Total withdrawal: $'..snapshot.total},
          {label='Manage / teleport',action=function() manage('four') end},
          {label='Back',action=back},
        }) end},
        {label='Route 5: '..(snapshot.route5 and snapshot.route5.name or 'Empty'),action=function() details(snapshot.route5,'ROUTE 5') end},
        {label=snapshot.pending and 'Egg READY at Four Island' or 'Egg status / compatibility',action=breeding},
        {label='Party eggs: '..#snapshot.eggs,action=function()
          local lines={}
          for _,egg in ipairs(snapshot.eggs) do
            lines[#lines+1]='Party slot '..egg.slot..(egg.bad and ': Bad Egg (cannot hatch)' or ': '..egg.cycles..' cycles left')
            if not egg.bad then lines[#lines+1]='Earliest hatch check: '..egg.steps..' steps' end
          end
          if session.version=='emerald' and #lines>0 then lines[#lines+1]='Hatch cycles per check: '..snapshot.hatchRate..' (Flame Body / Magma Armor).' end
          if #lines==0 then lines[1]='No eggs in your party.' else lines[#lines+1]='Multiple eggs can delay each other. Walking resumes after closing menus.' end
          info('PARTY EGGS',lines)
        end},
        {label='Manage / teleport',action=function() push('CHOOSE DAY CARE',{{label='Four Island',action=function() manage('four') end},{label='Route 5',action=function() manage('route5') end},{label='Back',action=back}}) end},
        {label='Refresh details',action=function() snapshot=Model.snapshot(session); home() end},
        {label='Help / controls',action=function() info('DAY CARE HELP',{
          'Up/Down: scroll. Left/Right: skip five rows. A: open. B/L: back. START: close.',
          'Route 5 trains one Pokemon. Four Island trains two and can produce eggs.',
          'Manage / teleport: change deposited Pokemon remotely or travel to either Day Care. Collect eggs in person.',
          'Training and move previews use the current engine. Reopen or Refresh for new data.',
          'Native FR/LG menus pause walking. This is your real Day Care, not Auto Breeder virtual parents.'}) end},
      })
    end
    home()
    function screen.handleInput(input)
      if not services.isActive(session) then Stack.pop('daycare-viewer'); Screen.active=nil; return end
      if input:wasPressed('start') then Stack.pop('daycare-viewer'); Screen.active=nil; return end
      if input:wasPressed('b') or input:wasPressed('l') then
        if input.pressed then input.pressed.b=nil;input.pressed.l=nil end
        back(); return
      end
      local page=screen.pages[#screen.pages]
      local delta=input:wasPressed('up') and -1 or input:wasPressed('down') and 1 or input:wasPressed('left') and -5 or input:wasPressed('right') and 5 or 0
      page.cursor=(page.cursor-1+delta)%#page.rows+1
      if input:wasPressed('a') and page.rows[page.cursor].action then page.rows[page.cursor].action() end
    end
    function screen.update()
      if not services.isActive(session) then Stack.pop('daycare-viewer'); Screen.active=nil end
    end
    function screen.draw() View.draw(screen) end
    Stack.push('daycare-viewer',screen,{fullscreen=true})
    return screen
  end
  return Screen
end
