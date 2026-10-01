return function(E,C)
  local A={}
  local Space=require('src.core.game3.scripting.space')
  local Stack=require('src.ui.game3.stack')
  function A.ready(session)
    local ok,why=E.ready(session)
    if not ok then return false,why end
    if require('src.core.game3.safari').isActive(session) then return false,'Finish the Safari game first.' end
    local Link=require('src.core.game3.link')
    if (Link.inLinkRoom and Link.inLinkRoom()) or
      require('src.core.game3.link.union_room').isUnionMap(session.map) then
      return false,'Leave the linked activity first.'
    end
    local allowed={start=true,mod_manager=true,['pokemon-services']=true}
    for _,layer in ipairs(Stack._layers) do
      if not allowed[layer.id] then return false,'Close the other game screen first.' end
    end
    return true
  end
  function A.closeMenus()
    Stack.pop('pokemon-services')
    local Manager=require('src.ui.game3.mod_manager')
    if Manager.isOpen() then Manager.close() end
    local Start=require('src.ui.game3.start_menu')
    if Start.isOpen() then Start.close(true) end
  end
  function A.heal(session)
    local ok,why=A.ready(session);if not ok then return false,why end
    if not session.party or #session.party==0 then return false,'Your party is empty.' end
    -- Same routine invoked by the engine's HealPlayerParty special.
    require('src.core.game3.party').healAll(session.party)
    return true,'Your party is fully healed. Save normally to keep changes.'
  end
  local function emeraldDeleter(key)
    -- Emerald's retail script expects party cancel=255. The shared host picker
    -- returns 6/7. Clone only this service graph; leave the imported scripts intact.
    local scripts=Space.vm.scripts;local copied={}
    local function clone(source)
      if not scripts[source] then return source end
      local target='pokemon-services:deleter:'..source
      if copied[source] then return target end
      copied[source]=true;local rows={};scripts[target]=rows
      for i,op in ipairs(scripts[source])do
        local row={};for k,v in pairs(op)do row[k]=v end;rows[i]=row
        if type(row.target)=='string' then row.target=clone(row.target) end
      end
      for i,row in ipairs(rows)do
        local branch=rows[i+1]
        if row.op=='compare_var_to_value' and row.var==0x8004 and row.value==255
          and branch and branch.op=='goto_if' and branch.cond==1 then
          row.value=6;row[2]=6;branch.cond=4;branch[1]=4
        end
      end
      return target
    end
    return clone(key)
  end
  function A.script(session,kind)
    local ok,why=A.ready(session);if not ok then return false,why end
    local key=C.script(Space.bundle,kind)
    if kind=='reminder' and Space.vm then
      -- Native party chooser, eligibility queries and learning UI, without the
      -- retail merchant's mushroom checks, payment dialogue or item removal.
      local S=require('src.core.game3.scripting.stdscripts').SPECIAL
      if session.version=='emerald' then S=require('src.core.game3.constants').of('emerald').specials.byName end
      key='pokemon-services:free-reminder'
      local finish=key..':end'
      Space.vm.scripts[finish]={{op='release'},{op='end'}}
      Space.vm.scripts[key]={
        {op='lock'},
        {op='special',id=S.ChooseMonForMoveRelearner},{op='waitstate'},
        {op='compare_var_to_value',var=0x8004,value=6},
        {op='goto_if',cond=4,target=finish},
        {op='special',id=session.version=='emerald' and S.IsSelectedMonEgg or 328}, -- Native IsSelectedMonEgg query.
        {op='compare_var_to_value',var=0x800D,value=1},
        {op='goto_if',cond=1,target=finish},
        {op='compare_var_to_value',var=0x8005,value=0},
        {op='goto_if',cond=1,target=finish},
        {op='special',id=S.TeachMoveRelearnerMove},{op='waitstate'},
        {op='release'},{op='end'},
      }
    end
    if not (key and Space.vm and Space.vm.scripts[key]) then return false,'This native service script is unavailable.' end
    if kind=='deleter' and session.version=='emerald' then key=emeraldDeleter(key) end
    A.closeMenus()
    -- Local ID zero means no unrelated NPC at the current map is selected.
    -- The normal VM owns dialogue, payment, choice screens and field locking.
    if not Space.startScript(key,0) then return false,'The game could not start this service.' end
    Space.vm:tick()
    return true
  end
  function A.shop(session,key)
    local ok,why=A.ready(session);if not ok then return false,why end
    local items=require('src.core.game3.marts').itemsFor(key)
    if not items or #items==0 then return false,'This shop inventory is unavailable.' end
    A.closeMenus()
    require('src.ui.game3.shop_menu').show({session=session,items=items})
    return true
  end
  function A.open(session,kind)
    local ok,why=A.ready(session);if not ok then return false,why end
    if kind=='pc' or kind=='items' then
      A.closeMenus()
      require('src.ui.game3.pc_menu').show({session=session,startMode=kind=='pc' and 'storage' or 'player_pc',closeOnExit=true})
      return true
    end
    return false,'Unknown service.'
  end
  return A
end
