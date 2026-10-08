return function(mod)
 local Support=assert(load(mod:read('support.lua')))()
 local M=assert(load(mod:read('model.lua')))()
 mod.options:define({{key='enabled',label='ENABLED',type='toggle',default=true},
  {key='feebas_reveal',label='REVEAL FEEBAS SPOTS',type='toggle',default=false}})
 local api=Support.new(mod);local baseActive=api.active
 api.active=function()return baseActive() and require('src.core.game3.profile').active().family=='rse'end
 local req=function(n)return require('src.core.game3.'..n)end
 local s,game;local show,root
 local function name(mon)return mon.nickname and mon.nickname~='' and mon.nickname or req('pokemon').name(mon.species)end
 local function text(rows,t)for _,line in ipairs(api.lines(t))do rows[#rows+1]={label=line}end end
 local function page(title,rows,back)
  rows[#rows+1]={label='Back',back=true,choose=function()end}
  local screen=api.menu(title,rows)
  local handle=screen.handleInput
  screen.handleInput=function(input)
   if not api.active() or s~=api.session() then screen.close();return end
   return handle(input)
  end
  return screen
 end
 local function location(rows,loc)
  text(rows,loc and (M.pretty(loc.map)..' ('..loc.x..', '..loc.y..')') or 'Location unavailable')
 end
 local function notice(message,back)local rows={};text(rows,message);return page('HOENN TOOLS',rows,back)end
 local function act(fn,back)
  if not api.active() or s~=api.session() then return notice('Save or mod changed. Reopen Hoenn Tools.')end
  local _,why=fn(s);return notice(why,back)
 end
 local function rematches()
  local rows={};for _,r in ipairs(M.rematches(s))do
   local e=r;rows[#rows+1]={label=(e.gym and 'GYM: ' or '')..e.name..' READY',choose=function()
    local detail={};text(detail,e.location);text(detail,'Travel there and challenge the trainer normally.');page(e.name,detail,rematches)
   end}
  end
  if #rows==0 then text(rows,'No rematches ready.')end
  page(s.version=='emerald' and 'MATCH CALL' or "TRAINER'S EYES",rows)
 end
 local stages={'Planted','Sprouted','Growing','Flowering','Ready to harvest'}
 local function berries()
  local rows={};for _,patch in ipairs(M.berryPatches(s))do local e=patch
   rows[#rows+1]={label=e.label,choose=function()
    local detail={}
    detail[#detail+1]={label='Teleport to patch',choose=function()
     if not api.active() or s~=api.session()then return end
     local ok,why=M.teleportBerryPatch(s,e.id);if not ok then notice(why,berries)end
    end}
    location(detail,e.location)
    text(detail,'One destination for '..#e.trees..' nearby planting spots.')
    for _,tree in ipairs(e.trees)do
     text(detail,tree.name..': '..(stages[tree.stage] or 'Empty'))
     if tree.stage==5 then text(detail,'Harvest: '..tree.yield..' berries')
     elseif tree.stage>0 then
      text(detail,'Next stage: '..tree.minutes..' in-game minutes')
      text(detail,tree.watered and 'Watered this stage' or 'Not watered this stage')
     end
     if tree.paused then text(detail,'Growth paused until the tree is seen.')end
    end
    page('BERRY PATCH',detail,berries)
   end}
  end
  if #rows==0 then text(rows,'No berry locations available.')end
  page('BERRY GARDEN',rows)
 end

 local frontier
 local function facility(index)
  local f=M.frontier(s,index);local rows={}
  text(rows,'BP: '..f.bp..' / Symbols: '..f.symbols..'/2');text(rows,f.rule)
  if f.active then text(rows,'Challenge in progress: viewing only.')end
  for _,e in ipairs(f.rows)do
   text(rows,({'Singles','Doubles','Multi','Link Multi'})[e.mode+1]..' '..(e.level==0 and 'L50' or 'Open')..': '..e.current..' / best '..e.record)
  end
  for level=0,1 do local lvl=level
   rows[#rows+1]={label='Check party trio: '..(lvl==0 and 'Level 50' or 'Open level'),choose=function()
    local chosen={};local selectParty
    selectParty=function()
     local opts={};for slot,mon in ipairs(s.party or {})do local ix=slot
      opts[#opts+1]={label=(chosen[ix] and '[X] ' or '[ ] ')..(name(mon)),choose=function()chosen[ix]=not chosen[ix];selectParty()end}
     end
     opts[#opts+1]={label='Check selected trio',choose=function()
      local slots={};for ix=1,6 do if chosen[ix]then slots[#slots+1]=ix end end
      local result={};if #slots~=3 then text(result,'Select exactly three Pokemon.')else
       for _,line in ipairs(M.eligibility(s,index,lvl,slots))do text(result,line)end
       text(result,'For standard three-Pokemon entry only. Native reception confirms final eligibility.')
      end
      page('ENTRY CHECK',result,selectParty)
     end}
     page('CHOOSE THREE',opts,function()facility(index)end)
    end
    selectParty()
   end}
  end
  page('BATTLE '..f.name:upper(),rows,frontier)
 end
 frontier=function()
  if s.version~='emerald' then
   local rows={};text(rows,'Native three-Pokemon Singles; Level 50 or Level 100.')
   for _,r in ipairs(M.tower(s))do text(rows,'Level '..r.level..': '..r.current..' / best '..r.record)end
   text(rows,'Reception confirms final entry eligibility.')
   for level=0,1 do local lvl=level
    rows[#rows+1]={label='Check party trio: Level '..(lvl==0 and '50' or '100'),choose=function()
     local chosen={};local selectParty
     selectParty=function()
      local opts={};for slot,mon in ipairs(s.party or {})do local ix=slot
       opts[#opts+1]={label=(chosen[ix] and '[X] ' or '[ ] ')..name(mon),choose=function()chosen[ix]=not chosen[ix];selectParty()end}
      end
      opts[#opts+1]={label='Check selected trio',choose=function()
       local slots={};for ix=1,6 do if chosen[ix]then slots[#slots+1]=ix end end
       local result={};for _,line in ipairs(M.eligibility(s,1,lvl,slots))do text(result,line)end
       page('ENTRY CHECK',result,selectParty)
      end}
      page('CHOOSE THREE',opts,frontier)
     end
     selectParty()
    end}
   end
   return page('BATTLE TOWER',rows)
  end
  local rows={};for i,f in ipairs(M.facilities)do local index=i;rows[#rows+1]={label='Battle '..f.name,choose=function()facility(index)end}end
  page('BATTLE FRONTIER',rows)
 end
 local feebas
 feebas=function()
  local reveal=mod.options:get('feebas_reveal')==true;local f=M.feebas(s,reveal);local rows={}
  if f.message then text(rows,f.message)else
   text(rows,'Facing tile '..f.x..', '..f.y)
   if f.id then
    text(rows,'Spot '..f.id..(f.marked and ': marked searched' or ': unmarked'))
    if reveal then text(rows,f.valid and 'Feebas spot: YES (not every catch)' or 'Feebas spot: NO')end
    rows[#rows+1]={label=f.marked and 'Remove searched mark' or 'Mark tile searched',choose=function()act(M.markFeebas,feebas)end}
   else text(rows,'Face fishable water, not a waterfall.')end
  end
  text(rows,'Reveal is optional in QoL settings. Marks reset when the Dewford seed changes.')
  rows[#rows+1]={label='Open Shiny Hunter',choose=function()
   local hunter=mod.find and mod.find('shiny_hunter')
   if hunter and hunter.exports and hunter.exports.show and hunter.exports.show(game) then return end
   notice('Enable the updated Shiny Hunter to use fishing hunts.',feebas)
  end}
  text(rows,'Choose fishing in Shiny Hunter at this position. Encounter odds remain native.')
  page('FEEBAS ASSISTANT',rows)
 end
 local contests
 local function pokemonContest(slot)
  local mon=s.party[slot];if not mon then return contests()end
  local P=req('rse.pokeblock');local rows={};local condition=M.copy(mon.contest or {})
  text(rows,'Likes: '..P.favoriteName(req('pokemon').natureId(mon.personality)))
  for _,key in ipairs({'cool','beauty','cute','smart','tough','sheen'})do text(rows,key:upper()..': '..(condition[key] or 0)..'/255')end
  rows[#rows+1]={label='Preview Pokeblocks',choose=function()
   local options={}
   for index,block in ipairs(s.pokeblocks or {})do if (block.color or 0)~=0 then local b=M.copy(block)
    options[#options+1]={label=index..': '..P.name(b),choose=function()
     local v=M.preview(mon,b);local lines={};text(lines,v.allowed and 'Preview only: no feeding or item use.' or 'Sheen is full: cannot feed.')
     for _,key in ipairs({'cool','beauty','cute','smart','tough','sheen'})do text(lines,key:upper()..': '..(v.before[key]or 0)..' -> '..(v.after[key]or 0))end
     page('FEEDING PREVIEW',lines,function()pokemonContest(slot)end)
    end}
   end end
   if #options==0 then text(options,'No Pokeblocks in your case.')end
   page('POKEBLOCK PLANNER',options,function()pokemonContest(slot)end)
  end}
  rows[#rows+1]={label='Contest moves / combos',choose=function()
   local moves={};for _,v in ipairs(M.contestMoves(mon))do local e=v
    moves[#moves+1]={label=e.name..' / '..e.category,choose=function()
     local detail={};text(detail,'Appeal: '..(e.appeal==255 and '--' or e.appeal/10)..' / Jam: '..(e.jam==255 and '--' or e.jam/10))
     text(detail,e.description);text(detail,#e.combos>0 and ('Follow with: '..table.concat(e.combos,', ')) or 'No following combo among current moves.')
     page(e.name,detail,function()pokemonContest(slot)end)
    end}
   end
   page('CONTEST MOVES',moves,function()pokemonContest(slot)end)
  end}
  page(name(mon),rows,contests)
 end
 contests=function()
  local rows={};for i,m in ipairs(s.party or {})do if not req('pokemon').isEgg(m)then local ix=i
   rows[#rows+1]={label=name(m),choose=function()pokemonContest(ix)end}
  end end
  page('CONTEST PLANNER',rows)
 end
 local function daily()
  local d=M.daily(s);local rows={};text(rows,('Game clock: %02d:%02d'):format(d.time.hours or 0,d.time.minutes or 0))
  text(rows,'Shoal Cave: '..(d.high and 'HIGH tide' or 'LOW tide'))
  text(rows,'Next tide at '..string.format('%02d:00',((d.time.hours or 0)+d.nextHours)%24)..'. Re-enter the cave to apply.')
  text(rows,d.mirage and 'Mirage Island: party qualifies today' or 'Mirage Island: no party match today')
  if d.weather then text(rows,d.weather)end;if d.ending then text(rows,'Weather event is ending; check the Institute.')end
  page('HOENN DAILY EVENTS',rows)
 end
 local bases,registry
 registry=function()
  local rows={}
  for _,entry in ipairs(M.registry(s))do local e=entry;local expected=s.secretBases[e.id+1]
   rows[#rows+1]={label=e.name,choose=function()
    page('REMOVE REGISTRATION?',{
     {label='Keep registered',back=true,choose=function()end},
     {label='Remove '..e.name,replace=true,choose=function()act(function(save)return M.unregister(save,e.id,expected)end,registry)end},
    },registry)
   end}
  end
  if #rows==0 then text(rows,'No registered bases.')end
  page('REGISTERED BASES',rows,bases).refresh=registry
 end
 bases=function()
  local rows={};for _,r in ipairs(M.bases(s))do local e=r
   rows[#rows+1]={label=e.name,choose=function()
    local detail={};location(detail,e.location);text(detail,e.registered and 'Registered base' or 'Not registered')
    if e.index>0 then text(detail,e.battled and 'Owner already battled today' or 'Owner not battled today; native requirements apply')end
    local D=req('rse.decoration_inventory');for _,id in ipairs(e.decorations)do if id~=0 then text(detail,(D.info(id)or{}).name or tostring(id))end end
    text(detail,'Use the base PC to arrange decorations and manage registration.');page('SECRET BASE',detail,bases)
   end}
  end
  if #rows==0 then text(rows,'No secret bases recorded.')end
  rows[#rows+1]={label='Decoration inventory',choose=function()
   local detail={};for _,e in ipairs(M.decorations(s))do text(detail,e.name)end
   if #detail==0 then text(detail,'No decorations owned.')end;page('DECORATIONS',detail,bases)
  end}
  rows[#rows+1]={label='Arrange own base decorations',choose=function()local ok,why=M.openDecorations(s);if not ok then notice(why,bases)end end}
  rows[#rows+1]={label='Manage registered bases',choose=registry}
  page('SECRET BASE TOOLS',rows)
 end
 root=function(cursor,status)
  if not api.active() or s~=api.session()then return end
  local screen=api.menu('HOENN TOOLS',{
   {label=s.version=='emerald' and 'Match Call companion' or "Trainer's Eyes companion",choose=rematches},{label='Berry garden',choose=berries},
   {label=s.version=='emerald' and 'Battle Frontier' or 'Battle Tower',choose=frontier},{label='Feebas assistant',choose=feebas},
   {label='Contest / Pokeblock planner',choose=contests},{label='Bike: '..M.bikeName(s)..' (A: switch)',replace=true,choose=function()
    if not api.active() or s~=api.session()then return end
    local ok,why=M.swapBike(s);root(6,not ok and why or nil)
   end},
   {label='Daily events',choose=daily},{label='Secret base tools',choose=bases},
   {label='Back',back=true,choose=function()end},
  })
  screen.cursor=cursor or 1
  if status then local lines={};text(lines,status);for i=#lines,1,-1 do table.insert(screen.rows,7,lines[i])end end
 end
 show=function(g)
  if not api.active()then return false end
  game=g or req('runtime')._game;M.game=game;s=api.session();if not s then return false end
  root();return true
 end
 api.startItem('HOENN TOOLS',show)
 mod.exports.show=show;mod.exports.model=M
 mod.exports.showRematches=function(g)if not api.active()then return false end;game=g or req('runtime')._game;M.game=game;s=api.session();if not s then return false end;rematches();return true end
end
