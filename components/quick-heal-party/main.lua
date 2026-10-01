return function(mod)
  local function module(name) return assert(load(assert(mod:read(name..'.lua')),'@quick-heal-party/'..name..'.lua'))() end
  mod.options:define({
    {key='enabled',label='ENABLED',type='toggle',default=true},
    {key='premium',label='USE PREMIUM MEDICINE',type='toggle',default=false},
    {key='revive',label='REVIVE FAINTED',type='toggle',default=true},
    {key='cure',label='CURE STATUS',type='toggle',default=true},
  })
  local E=module('runtime')(mod)
  local Screen=module('screen')(module('model'),module('menu')(module('view')),E)
  E.start('QUICK HEAL',Screen.show)
  E.helpLease(function()
    local top=require('src.ui.game3.stack').top()
    return top and top.id==mod.id
  end)
  mod.exports.show=Screen.show
end
