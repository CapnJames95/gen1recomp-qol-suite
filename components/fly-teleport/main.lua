return function(mod)
  local function module(name)
    return assert(load(assert(mod:read(name..'.lua')), '@fly-teleport/'..name..'.lua'))()
  end
  mod.options:define({
    {key='enabled',label='ENABLED',type='toggle',default=true},
    {key='all_unlocked',label='UNLOCK ALL',type='toggle',default=false},
  })
  local E = module('runtime')(mod)
  local Travel = module('travel')(mod)
  local Catalog = module('catalog')
  local Menu = module('menu')(module('view'))
  local function show(session)
    if not E.active(session) then return end
    local ui = Menu.new(mod.id,session,function() return E.active(session) end)
    local function allUnlocked() return E.get('all_unlocked') == true end
    local function unlocked(destination)
      return Catalog.unlocked(session,destination.section,allUnlocked())
    end
    local toggle = {help='A: toggle Unlock All  B/L: back'}
    toggle.label = function() return 'Unlock All: '..(allUnlocked() and 'ON' or 'OFF') end
    toggle.action = function()
      local saved = E.set('all_unlocked',not allUnlocked())
      toggle.help = saved and 'A: toggle Unlock All  B/L: back' or 'Could not save. Use mod settings.'
    end
    local rows = {}
    for _, entry in ipairs(Catalog.list()) do
      local destination = entry
      rows[#rows+1] = {label=function()
        return (unlocked(destination) and '' or '[LOCKED] ')..destination.name
      end,action=function()
        if not unlocked(destination) then
          ui.info('DESTINATION LOCKED',{'Visit '..destination.name..' during normal play, or switch Unlock All to ON at the bottom of the destinations list.'})
          return
        end
        ui.push('TELEPORT: '..destination.name:upper(),{
          {label='Cancel',action=ui.back},
          {label='Teleport now',action=function()
            local ready, why = E.ready(session)
            if ready and not unlocked(destination) then
              ready,why=false,'This destination is locked by game progression.'
            end
            Travel.game = E.game
            if ready then ready, why = Travel.ready() end
            local point
            if ready then point, why = Catalog.destination(destination.section); ready = point ~= nil end
            if ready then point, why = Travel.destination(point); ready = point ~= nil end
            if ready then ready, why = Travel.warp(point) end
            if ready then
              ui.close()
              require('src.ui.game3.start_menu').close(true)
            else
              ui.info('TELEPORT UNAVAILABLE',{why or 'Return to the field and try again.'})
            end
          end},
          {label=function() return allUnlocked() and 'All destinations unlocked.' or 'Unlocks follow game progression.' end},
          {label='Normal map entry scripts still run.'},
        })
      end}
    end
    rows[#rows+1] = toggle
    rows[#rows+1] = {label='Help / controls',action=function()
      ui.info('FLY TELEPORT HELP',{
        'Unlock All ON: all '..#Catalog.list()..' Fly destinations are available. OFF: destinations unlock when their native visited flags are set.',
        'Toggle Unlock All after the last destination with A or a tap. The same UNLOCK ALL option is in the mod manager. Locked destinations remain listed.',
        'No Fly move, badge or ferry ticket is required. Native map entry scripts still run.',
        'Choose a location, then confirm. Land on foot at its normal Fly landing point.',
        'Finish battles, dialogue, movement, linked activities and Safari games before teleporting.',
        'Up/Down: scroll. Left/Right: skip five. A: choose. B/L: back. START: close.',
      })
    end}
    rows[#rows+1] = {label='Close',action=ui.close}
    ui.push('FLY TELEPORT',rows)
    return ui
  end
  E.start('TELEPORT',show)
  E.helpLease(function()
    local top=require('src.ui.game3.stack').top()
    return top and top.id==mod.id
  end)
  mod.exports.show=show
end
