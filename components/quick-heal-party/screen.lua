return function(Model,Menu,services)
  local Screen={}
  function Screen.show(session)
    local ui=Menu.new('quick-heal-party',session,function() return services.active(session) end)
    Screen.active=ui
    local home
    local function options() return {premium=services.get('premium'),revive=services.get('revive'),cure=services.get('cure')} end
    local function preview(slot)
      local plan=Model.plan(session,options(),slot)
      local function itemRows()
        local rows={}
        local Items=require('src.core.game3.items_data')
        for id=13,29 do if plan.totals[id] then rows[#rows+1]={label=Items.displayName(id)..' x'..plan.totals[id]} end end
        if #rows==0 then rows[1]={label='No eligible items needed / available.'} end
        rows[#rows+1]={label='Back',action=ui.back}
        ui.push('ITEMS TO SPEND',rows)
      end
      local function results()
        local lines={}
        for i,mon in ipairs(plan.after) do
          if not slot or slot==i then
            local before=plan.beforeParty[i]
            lines[#lines+1]=Model.name(mon)..': '..tostring(before.hp)..' -> '..tostring(mon.hp)..'/'..tostring(mon.maxHp or mon.maxhp or '?')
            lines[#lines+1]=Model.usable(mon) and ('Status: '..(Model.status(before) or 'OK')..' -> '..(Model.status(mon) or 'OK')) or 'Egg / unavailable: skipped.'
          end
        end
        ui.info('PARTY AFTER HEALING',lines)
      end
      local rows={
        {label='Cancel',action=ui.back},
        {label='Items to spend: '..#plan.steps,action=itemRows},
        {label='Preview party results',action=results},
        {label='Still need care: '..plan.remaining},
      }
      if #plan.steps>0 then rows[#rows+1]={label='Confirm: use '..#plan.steps..' item(s)',action=function()
        local ok,message=Model.apply(session,plan,function() return services.ready(session) end)
        home(); ui.info(ok and 'HEALING COMPLETE' or 'HEALING STOPPED',{message,'Save normally to keep your changes.'})
      end} end
      ui.push('REVIEW QUICK HEAL',rows)
    end
    local function party()
      local rows={}
      for i,mon in ipairs(session.party or {}) do
        local slot=i
        rows[#rows+1]={label=Model.name(mon)..' '..tostring(mon.hp or 0)..'/'..tostring(mon.maxHp or mon.maxhp or 0),action=function() preview(slot) end}
      end
      rows[#rows+1]={label='Back',action=ui.back};ui.push('CHOOSE POKEMON',rows)
    end
    local function settings()
      local rows={}
      for _,entry in ipairs({{'premium','Use premium medicine'},{'revive','Revive fainted Pokemon'},{'cure','Cure status conditions'}}) do
        local key,label=entry[1],entry[2]
        rows[#rows+1]={label=function() return label..': '..(services.get(key) and 'ON' or 'OFF') end,
          action=function() services.set(key,not services.get(key)) end}
      end
      rows[#rows+1]={label='Back',action=ui.back};ui.push('HEALING PREFERENCES',rows)
    end
    home=function()
      ui.pages={}
      ui.push('QUICK HEAL PARTY',{
        {label='Preview healing: whole party',action=function() preview() end},
        {label='Heal one Pokemon',action=party},
        {label='Healing preferences',action=settings},
        {label='Help / controls',action=function() ui.info('QUICK HEAL HELP',{
          'Preview the items and party results, then confirm to spend medicine from your Bag.',
          'Party order gets priority when supplies run short. A partial heal is still useful.',
          'Premium medicine is OFF by default: keeps Full Restores, Max Potions and Max Revives.',
          'Berries, bitter herbs, Sacred Ash and PP items are never selected. Eggs are skipped.',
          'Uses a small sufficient HP item, or the largest available if none is enough. This is not a global cheapest-cost solver.',
          'Up/Down: scroll. Left/Right: skip five. A: choose. B/L: back. START: close.'}) end},
        {label='Close',action=ui.close},
      })
    end
    home();return ui
  end
  return Screen
end
