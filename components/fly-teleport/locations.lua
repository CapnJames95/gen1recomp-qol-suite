-- Per-save data: no global files and no coordinates shared between editions.
local M={limit=50}
function M.data(s)
 s.modData=s.modData or {};local d=s.modData.fly_teleport
 if type(d)~='table' or d.version~=s.version then d={version=s.version,saved={},recent={},favourites={},visited={},mode=1};s.modData.fly_teleport=d end
 return d
end
function M.copy(p)local n={};for k,v in pairs(p)do if type(v)~='table' then n[k]=v end end;return n end
function M.name(value)
 if type(value)~='string' then return nil end
 local clean=value:gsub('[%c]',''):match('^%s*(.-)%s*$');local chars={}
 for ch in clean:gmatch('[%z\1-\127\194-\244][\128-\191]*')do if #chars==16 then break end;chars[#chars+1]=ch end
 local n=table.concat(chars)
 return n~='' and n or nil
end
function M.save(s,point,name,index)
 local d=M.data(s);name=M.name(name)
 if not name then return false,'Enter a name.' end
 if not index and #d.saved>=M.limit then return false,'50 locations saved. Replace or delete one first.' end
 if index and not d.saved[index] then return false,'Location no longer exists.' end
 local p=M.copy(point);p.name=name;p.version=s.version;p.id=index and d.saved[index].id or ('saved:'..tostring(d.nextId or 1))
 if not index then d.nextId=(d.nextId or 1)+1 end
 d.saved[index or #d.saved+1]=p;return true
end
function M.remember(s,point,origin)
 local d=M.data(s);d.previous=M.copy(origin)
 local key=point.map..':'..point.x..':'..point.y
 for i=#d.recent,1,-1 do local p=d.recent[i];if p.map..':'..p.x..':'..p.y==key then table.remove(d.recent,i) end end
 table.insert(d.recent,1,M.copy(point));while #d.recent>10 do table.remove(d.recent) end
end
return M
