-- Resolve services from the user's imported scripts, never edition-specific ROM addresses.
local C={}
local function object(bundle,map,id)
  local events=bundle and bundle.events and bundle.events[map]
  for _,o in ipairs(events and events.objects or {}) do
    if o.localId==id then return o.scriptKey end
  end
end
C.object=object
function C.script(bundle,kind)
  local sites={reminder={'FR_TWO_ISLAND_HOUSE',1},deleter={'FR_FUCHSIA_CITY_HOUSE3',1},
    naming={'FR_LAVENDER_TOWN_HOUSE2',1},two={'FR_TWO_ISLAND',1}}
  if require('src.core.GameVersion').get()=='emerald' then
    sites={reminder={'EM_FALLARBOR_TOWN_MOVE_RELEARNERS_HOUSE',1},deleter={'EM_LILYCOVE_CITY_MOVE_DELETERS_HOUSE',1},naming={'EM_SLATEPORT_CITY_NAME_RATERS_HOUSE',1}}
  end
  local site=sites[kind]
  if site then return object(bundle,site[1],site[2]) end
  if kind=='vending' then
    local emerald=require('src.core.GameVersion').get()=='emerald'
    local events=bundle and bundle.events and bundle.events[emerald and 'EM_LILYCOVE_CITY_DEPARTMENT_STORE_ROOFTOP' or 'FR_CELADON_CITY_DEPARTMENT_STORE_ROOF']
    for _,o in ipairs(events and events.bgEvents or {}) do
      if (o.x==(emerald and 9 or 10)) and o.y==(emerald and 1 or 3) then return o.scriptKey end
    end
  end
end
-- Shop inventory is read from the clerk's actual pokemart operand.
-- Branching stock (Two Island) is handled by its complete original script.
function C.inventoryKeys(bundle,key,seen,out)
  seen,out=seen or {},out or {}
  if not key or seen[key] then return out end
  seen[key]=true
  for _,op in ipairs(bundle.scripts[key] or {}) do
    if op.op=='pokemart' then out[op.items or op.ptr or op[1]]=true end
    if op.target then C.inventoryKeys(bundle,op.target,seen,out) end
  end
  return out
end
function C.shops(bundle,department)
  local rows={}
  if not (bundle and bundle.events and bundle.scripts) then return rows end
  for map,events in pairs(bundle.events) do
    local dept=(map:find('^FR_CELADON_CITY_DEPARTMENT_STORE_')~=nil or map:find('^EM_LILYCOVE_CITY_DEPARTMENT_STORE_')~=nil)
    if (department and dept) or (not department and not dept) then
      for _,o in ipairs(events.objects or {}) do
        local keys=C.inventoryKeys(bundle,o.scriptKey)
        local key,count=nil,0
        for k in pairs(keys) do key,count=k,count+1 end
        if count==1 then
          local label=map:gsub('^FR_',''):gsub('^EM_',''):gsub('_MART$',''):gsub('_',' ')
          if map=='FR_INDIGO_PLATEAU_POKEMON_CENTER_1F' then label='INDIGO PLATEAU' end
          if map=='FR_TRAINER_TOWER_LOBBY' then label='TRAINER TOWER' end
          if dept then
            local floor=map:match('_(%dF)$') or ''
            local names={['2F']={[2]='General goods',[3]='TMs'},['4F']={[3]='Evolution stones'},
              ['5F']={[3]='Vitamins',[4]='Battle items'}}
            if map:match('^EM_') then
              names={['2F']={[4]='Medicine',[5]='Balls / status cures'},['3F']={[4]='Vitamins',[5]='Battle items'},['4F']={[4]='Attack TMs',[5]='Support TMs'}}
            end
            label=floor..': '..((names[floor] or {})[o.localId] or ('Counter '..o.localId))
          end
          rows[#rows+1]={label=label,key=key,map=map,localId=o.localId}
        end
      end
    end
  end
  table.sort(rows,function(a,b) return a.label<b.label end)
  return rows
end
return C
