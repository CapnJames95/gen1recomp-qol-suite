-- Native-canvas geometry. Saved values never contain window/DPI coordinates.
local A = {}
local function number(value, fallback, lo, hi)
  if type(value)~='number' or value~=value or value==math.huge or value==-math.huge then return fallback end
  return math.max(lo,math.min(hi,value))
end
function A.clean(raw)
  raw=type(raw)=='table' and raw or {}
  return {scale=number(raw.scale,1,0.5,1.25),x=number(raw.x,1,0,1),y=number(raw.y,0,0,1)}
end
function A.bounds(raw,width,height)
  local a=A.clean(raw)
  local scale=math.min(a.scale,240/width,160/height)
  local w,h=width*scale,height*scale
  return {x=math.floor((240-w)*a.x+0.5),y=math.floor((160-h)*a.y+0.5),w=w,h=h,scale=scale}
end
function A.place(raw,width,height,x,y)
  local a=A.clean(raw);local b=A.bounds(a,width,height)
  a.x=number(x/math.max(0.001,240-b.w),a.x,0,1)
  a.y=number(y/math.max(0.001,160-b.h),a.y,0,1)
  return a
end
return A
