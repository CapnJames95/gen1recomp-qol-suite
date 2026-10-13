return function(mod)
 local function module(n)return assert(load(assert(mod:read(n..'.lua')),'@fly-teleport/'..n))()end
 mod.options:define({{key='enabled',label='ENABLED',type='toggle',default=true},{key='all_unlocked',label='UNLOCK ALL',type='toggle',default=false}})
 local E=module('runtime')(mod);local Travel=module('travel')(mod);local Catalog=module('catalog')
 local Locations=module('locations');local POI=module('poi');local Menu=module('menu')(module('view'))
 local function show(s)
  if not E.active(s) then return end
  local ui=Menu.new(mod.id,s,function()return E.active(s)end);local d=Locations.data(s);local root,details
  local function notice(why)ui.info('TELEPORT',{why or 'Unavailable.'})end
  local function ready()Travel.game=E.game or require('src.core.game3.runtime')._game;return E.ready(s)end
  local function point(e)
   local ok,why=ready();if not ok then return nil,why end
   if e.section then
    if not Catalog.unlocked(s,e.section,E.get('all_unlocked')) then return nil,'Visit '..e.name..' first, or turn Unlock All ON.' end
    local p,err=Catalog.destination(e.section);if p then p.name=e.name;p.id=e.id end;return p,err
   end
   if e.category then
    if not POI.unlocked(s,e,d.visited,E.get('all_unlocked')) then return nil,'Reach this area or visit this location to unlock it, or turn Unlock All ON.' end
    return Travel.poi(e)
   end
   return e
  end
  local function warp(e)
   local p,why=point(e);if not p then return notice(why)end
   local origin;origin,why=Travel.position();if not origin then return notice(why)end
   local checked;checked,why=Travel.destination(p);if not checked then return notice(why)end
   local ok;ok,why=Travel.warp(checked)
   if not ok then return notice(why)end
   Locations.remember(s,checked,origin);ui.close();require('src.ui.game3.start_menu').close(true)
  end
  local function namePoint(p,index)
   require('src.ui.game3.naming').open({template='PLAYER',title='LOCATION NAME',maxLen=16,initialText=index and d.saved[index].name or '',session=s,onDone=function(name)
    if not E.active(s) or ui.closed then return end
    if not name then return end
    local ok,why=Locations.save(s,p,name,index);if not ok then notice(why)else root(true)end
   end})
  end
  local function saveHere(index)
   local ok,why=ready();if not ok then return notice(why)end
   local p;p,why=Travel.position();if not p then return notice(why)end
   p,why=Travel.destination(p);if not p then return notice(why)end
   namePoint(p,index)
  end
  local function listPage(title,entries)
   local rows={};for _,e in ipairs(entries)do local entry=e;rows[#rows+1]={label=function()return (entry.category and not POI.unlocked(s,entry,d.visited,E.get('all_unlocked')) and '[LOCKED] ' or '')..entry.name end,action=function()details(entry)end}end
   rows[#rows+1]={label='Back',action=ui.back};ui.push(title,rows)
  end
  details=function(e,index)
   local key=e.id or e.map..':'..e.x..':'..e.y
   local rows={{label='Teleport now',action=function()warp(e)end},
    {label=function()return 'Favourite: '..(d.favourites[key] and 'ON' or 'OFF')end,action=function()d.favourites[key]=not d.favourites[key] or nil end}}
   if index then
    rows[#rows+1]={label='Rename',action=function()namePoint(e,index)end}
    rows[#rows+1]={label='Replace with current position',action=function()ui.push('REPLACE LOCATION?',{{label='Cancel',action=ui.back},{label='Replace',action=function()saveHere(index)end}})end}
    rows[#rows+1]={label='Move up',action=function()if index>1 then d.saved[index],d.saved[index-1]=d.saved[index-1],d.saved[index];root(true)end end}
    rows[#rows+1]={label='Move down',action=function()if index<#d.saved then d.saved[index],d.saved[index+1]=d.saved[index+1],d.saved[index];root(true)end end}
    rows[#rows+1]={label='Delete',action=function()ui.push('DELETE '..e.name..'?',{{label='Cancel',action=ui.back},{label='Delete',action=function()d.favourites[key]=nil;table.remove(d.saved,index);root(true)end}})end}
   end
   rows[#rows+1]={label='About this location',action=function()notice(e.description or (e.map and (e.map..' / '..e.x..', '..e.y) or 'Native Fly landing point.'))end}
   rows[#rows+1]={label='Back',action=ui.back};ui.push(e.name:upper(),rows)
  end
  root=function(reset)
   if reset then ui.pages={}end
   ready();local rows={}
   local fly=Catalog.list();for _,e in ipairs(fly)do e.id='fly:'..e.section end
   local pois=POI.list(s,Travel.game,mod);local all={};for _,list in ipairs({fly,pois,d.saved})do for _,e in ipairs(list)do all[#all+1]=e end end
   rows[#rows+1]={label='Fly Destinations',action=function()
    local entries={}
    for _,e in ipairs(fly)do local entry=e;entries[#entries+1]={label=function()return (Catalog.unlocked(s,entry.section,E.get('all_unlocked')) and '' or '[LOCKED] ')..entry.name end,action=function()details(entry)end}end
    entries[#entries+1]={label='Back',action=ui.back};ui.push('FLY DESTINATIONS',entries)
   end}
   rows[#rows+1]={label='Points of Interest',action=function()
    local entries={}
    for _,category in ipairs({'Services','Activities','Exploration','Collecting','Training'})do
     for _,e in ipairs(pois)do if e.category==category then entries[#entries+1]=e end end
    end
    listPage('POINTS OF INTEREST',entries)
   end}
   local function savedPage()
    local entries={{label='Save current position',action=function()saveHere()end}}
    for i,e in ipairs(d.saved)do local index,entry=i,e;entries[#entries+1]={label=entry.name,action=function()details(entry,index)end}end
    entries[#entries+1]={label='Back',action=ui.back};ui.push('SAVED LOCATIONS',entries)
   end
   rows[#rows+1]={label='Saved Locations',action=savedPage}
   local tour=mod.find('encounter_tour');if tour and tour.exports and tour.exports.show then rows[#rows+1]={label='Encounter destinations',action=function()ui.close();tour.exports.show(Travel.game)end}end
   rows[#rows+1]={label='Favourites',action=function()local favourites={};for _,e in ipairs(all)do if d.favourites[e.id]then favourites[#favourites+1]=e end end;listPage('FAVOURITES',favourites)end}
   rows[#rows+1]={label='Recent destinations',action=function()listPage('RECENT',d.recent)end}
   rows[#rows+1]={label='Return to previous location',action=function()if d.previous then details(d.previous)else notice('No return point yet.')end end}
   rows[#rows+1]={label='Help',action=function()notice('A: choose. Choose Fly Destinations, Points of Interest or Saved Locations to open its list. Left/Right skips five rows. Saved locations and names belong to this save; save normally to keep changes. Water arrivals require the HM and badge. POIs use existing save progress and recorded visits. Areas without native visit records use area milestones. Unlock All overrides progression. Restricted activities and blocked tiles cannot be used.')end}
   rows[#rows+1]={label=function()return 'Unlock All: '..(E.get('all_unlocked') and 'ON' or 'OFF')end,action=function()if not E.set('all_unlocked',not E.get('all_unlocked'))then notice('Could not save option.')end end}
   rows[#rows+1]={label='Close',action=ui.close};ui.push('TELEPORT',rows)
   if reset then savedPage() end
  end
  root();return ui
 end
 E.start('TELEPORT',show);E.helpLease(function()local t=require('src.ui.game3.stack').top();return t and t.id==mod.id end)
 mod.hooks:wrap('input.step',function(next,game,dt)
  E.game=game;local s=game and game.session
  if s and E.active(s) and game.phase=='field' then
   local id=require('src.core.game3.map').current or s.map
   if type(id)=='string' then Locations.data(s).visited[id]=true end
  end
  return next(game,dt)
 end)
 mod.exports.show=show
end
