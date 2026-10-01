-- Data-only layout. Never persists host entries, closures, or game state.
local Layout = {}
local native = {pokedex=true,pokemon=true,bag=true,trainer=true,trainer_link=true,
  save=true,option=true,mods=true,exit=true,retire=true}
function Layout.clean(raw)
  raw = type(raw)=='table' and raw or {}
  local s = {version=1,nextFolder=1,folders={},parents={},orders={}}
  local a=type(raw.appearance)=='table' and raw.appearance or {}
  local function number(v,default,lo,hi)
    if type(v)~='number' or v~=v or v==math.huge or v==-math.huge then return default end
    return math.max(lo,math.min(hi,v))
  end
  s.appearance={scale=number(a.scale,1,0.5,1.25),x=number(a.x,1,0,1),y=number(a.y,0,0,1)}
  local known = {root=true}
  for _,f in ipairs(type(raw.folders)=='table' and raw.folders or {}) do
    if type(f)=='table' and type(f.id)=='string' and f.id:match('^folder:%d+$')
        and not known[f.id] and type(f.name)=='string' and f.name:match('%S') then
      s.folders[#s.folders+1]={id=f.id,name=f.name}
      known[f.id]=true
      s.nextFolder=math.max(s.nextFolder,tonumber(f.id:match('%d+'))+1)
    end
  end
  for k,v in pairs(type(raw.parents)=='table' and raw.parents or {}) do
    if type(k)=='string' and known[v] and v~='root' then s.parents[k]=v end
  end
  for where,order in pairs(type(raw.orders)=='table' and raw.orders or {}) do
    if known[where] and type(order)=='table' then
      local seen, out = {}, {}
      for _,k in ipairs(order) do
        if type(k)=='string' and not seen[k] then out[#out+1]=k;seen[k]=true end
      end
      s.orders[where]=out
    end
  end
  return s
end
function Layout.entries(entries)
  local out, seen = {}, {}
  for _,e in ipairs(entries) do
    local base = e.id ~= nil and ('id:'..tostring(e.id)) or ('label:'..tostring(e.label))
    seen[base]=(seen[base] or 0)+1
    local key=base..(seen[base]>1 and ('#'..seen[base]) or '')
    out[#out+1]={key=key,label=e.label,entry=e,movable=not native[e.id]}
  end
  return out
end
function Layout.nodes(s,entries,where)
  local out={}
  for _,node in ipairs(Layout.entries(entries)) do
    local parent=node.movable and s.parents[node.key] or nil
    if (parent or 'root')==where then out[#out+1]=node end
  end
  if where=='root' then
    for _,f in ipairs(s.folders) do
      out[#out+1]={key=f.id,label=f.name,folder=true}
    end
  end
  local ranks={}
  for i,k in ipairs(s.orders[where] or {}) do ranks[k]=i end
  local source={}
  for i,n in ipairs(out) do source[n.key]=i end
  table.sort(out,function(a,b)
    local ar,br=ranks[a.key] or math.huge,ranks[b.key] or math.huge
    if ar~=br then return ar<br end
    return source[a.key]<source[b.key]
  end)
  return out
end
function Layout.order(s,where,nodes)
  local out,seen={},{}
  for _,n in ipairs(nodes) do out[#out+1]=n.key;seen[n.key]=true end
  -- Retain slots for temporarily unavailable mods.
  for _,k in ipairs(s.orders[where] or {}) do
    if not seen[k] then out[#out+1]=k end
  end
  s.orders[where]=out
end
function Layout.move(s,key,where)
  s.parents[key]=where~='root' and where or nil
  for _,order in pairs(s.orders) do
    for i=#order,1,-1 do if order[i]==key then table.remove(order,i) end end
  end
  s.orders[where]=s.orders[where] or {}
  s.orders[where][#s.orders[where]+1]=key
end
function Layout.create(s,name)
  local id='folder:'..s.nextFolder
  s.nextFolder=s.nextFolder+1
  s.folders[#s.folders+1]={id=id,name=name}
  return id
end
function Layout.delete(s,id)
  for i=#s.folders,1,-1 do if s.folders[i].id==id then table.remove(s.folders,i) end end
  for key,parent in pairs(s.parents) do if parent==id then s.parents[key]=nil end end
  s.orders[id]=nil
  for _,order in pairs(s.orders) do
    for i=#order,1,-1 do if order[i]==id then table.remove(order,i) end end
  end
end
return Layout
