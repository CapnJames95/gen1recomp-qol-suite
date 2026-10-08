return function(Menu,E,A,C,D)
  local Screen={}
  function Screen.show(session)
    if not E.active(session) then return end
    local emerald=require('src.core.game3.profile').forSession(session).family=='rse'
    local ui=Menu.new('pokemon-services',session,function() return E.active(session) end)
    local function info(ok,why)
      if not ok and not require('src.ui.game3.stack').has('pokemon-services') then
        ui=Menu.new('pokemon-services',session,function() return E.active(session) end)
      end
      if why then ui.info(ok and 'SERVICE COMPLETE' or 'CANNOT CONTINUE',{why}) end
    end
    local function call(fn) return function() local ok,why=fn();info(ok,why) end end
    local function confirm(title,label,fn)
      ui.push(title,{{label='Cancel',action=ui.back},{label=label,action=call(function()
        local ok,why=fn();ui.back();return ok,why
      end)}})
    end
    local function native(kind) return call(function() return A.script(session,kind) end) end
    local function shortcut(kind) return call(function() return A.open(session,kind) end) end
    local function shops(department)
      local rows={}
      for _,entry in ipairs(C.shops(require('src.core.game3.scripting.space').bundle,department)) do
        local key=entry.key
        rows[#rows+1]={label=entry.label,action=call(function() return A.shop(session,key) end)}
      end
      if department then rows[#rows+1]={label='Rooftop vending machines',action=native('vending')}
      elseif not emerald then rows[#rows+1]={label='TWO ISLAND (current stock)',action=native('two')} end
      rows[#rows+1]={label='Back',action=ui.back}
      ui.push(department and (emerald and 'LILYCOVE DEPT. STORE' or 'CELADON DEPT. STORE') or 'POKE MARTS',rows)
    end
    local function daycare(site)
      local function deposit()
        local rows={}
        for slot,mon in ipairs(session.party or {}) do
          local index,selected=slot,mon
          local name=require('src.core.game3.daycare').nickname(mon)
          rows[#rows+1]={label=name,action=function()
            confirm('DEPOSIT POKEMON?', 'Deposit '..name,function() return D.deposit(session,site,index,selected) end)
          end}
        end
        rows[#rows+1]={label='Back',action=ui.back};ui.push('CHOOSE PARTY POKEMON',rows)
      end
      local function overview()
        local rows={}
        for slot=1,(site=='four' and 2 or 1) do
          local quote=D.quote(session,site,slot)
          if quote then
            local index,selected=slot,quote
            local Daycare=require('src.core.game3.daycare')
            local name=Daycare.nickname(quote.mon)
            rows[#rows+1]={label=name..' / withdraw $'..quote.cost,action=function()
              confirm('WITHDRAW POKEMON?', 'Pay $'..selected.cost,function() return D.withdraw(session,site,index,selected) end)
            end}
          else rows[#rows+1]={label='Slot '..slot..': empty'} end
        end
        if site=='four' then
          local Daycare=require('src.core.game3.daycare')
          local root=session.modData and session.modData[Daycare.SAVE_KEY] or {}
          local dc=rawget(session,'daycare') or root.daycare or {}
          rows[#rows+1]={label=Daycare.isEggPending(dc) and (emerald and 'Egg ready: collect on Route 117' or 'Egg ready: collect on Four Island') or 'No egg waiting'}
        end
        rows[#rows+1]={label='Deposit from party',action=deposit}
        rows[#rows+1]={label='Refresh',action=function() ui.back();overview() end}
        rows[#rows+1]={label='Back',action=ui.back};ui.push(emerald and 'ROUTE 117 DAY CARE' or site=='four' and 'FOUR ISLAND DAY CARE' or 'ROUTE 5 DAY CARE',rows)
      end
      overview()
    end
    ui.push('POKEMON SERVICES',{
      {label='Pokemon PC',action=shortcut('pc')},
      {label='Item PC',action=shortcut('items')},
      {label='Heal entire party (free)',action=function() confirm('HEAL YOUR PARTY?','Heal now',function() return A.heal(session) end) end},
      {label='Poke Marts',action=function() shops(false) end},
      {label=emerald and 'Lilycove department store' or 'Celadon department store',action=function() shops(true) end},
      {label='Move Reminder (free)',action=native('reminder')},
      {label='Move Deleter',action=native('deleter')},
      {label='Name Rater',action=native('naming')},
      {label='Day Care',action=function() if emerald then return daycare('four') end;ui.push('DAY CARE',{
        {label='Route 5',action=function() daycare('route5') end},
        {label='Four Island',action=function() daycare('four') end},
        {label='Back',action=ui.back}}) end},
      {label='Help',action=function() ui.info('ABOUT SERVICES',{
        'Remote access to native game services. Shops use normal money, stock and bag limits.',
        emerald and 'The Move Reminder is free. No Heart Scales are required or consumed. Native move eligibility still applies.' or 'The Move Reminder is free. No mushrooms are required or consumed. Native move eligibility still applies.',
        emerald and 'Day Care uses normal fees. Collect waiting eggs on Route 117 before changing parents.' or 'Day Care uses normal fees. Collect waiting eggs on Four Island before changing parents.',
        emerald and 'Remote shops and services bypass travel. Lilycove lists native item counters and rooftop drinks; decoration counters are not included.' or 'Remote shops and services bypass travel. Two Island keeps its progression-dependent stock.',
        'Save through the normal START menu to keep changes. B returns; START closes.'}) end},
      {label='Close',action=ui.close},
    })
    local ok,why=A.ready(session)
    if not ok then ui.info('CANNOT CONTINUE',{why}) end
    return ui
  end
  return Screen
end
