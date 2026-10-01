return function(mod)
  assert(load(assert(mod:read("native_legality.lua")), "@pokemon-services/native_legality.lua"))().install(mod)
  local function module(name) return assert(load(assert(mod:read(name..'.lua')),'@pokemon-services/'..name..'.lua'))() end
  mod.options:define({{key='enabled',label='ENABLED',type='toggle',default=true}})
  local E=module('runtime')(mod)
  local C=module('catalog')
  local A=module('services')(E,C)
  local Daycare=module('daycare')({ready=function() return A.ready(require('src.core.game3.runtime').getSession()) end})
  local Screen=module('screen')(module('menu')(module('view')),E,A,C,Daycare)
  E.start('SERVICES',Screen.show)
  E.helpLease(function() local top=require('src.ui.game3.stack').top();return top and top.id==mod.id end)
  -- Native mod-manager detail entry, available only during an active field game.
  E.wrap(require('src.mods.ManagerState'),'detailRows',function(previous,self,m)
    local rows=previous(self,m)
    if m.id==mod.id and m.enabled and require('src.ui.game3.mod_manager').isOpen() then
      table.insert(rows,1,{label='OPEN SERVICES',action=function()
        E.game=require('src.core.game3.runtime')._game or E.game
        Screen.show(require('src.core.game3.runtime').getSession())
      end})
    end
    return rows
  end)
  mod.exports.show=Screen.show
end
