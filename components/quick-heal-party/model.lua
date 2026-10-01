local M = {}
local Bag = require('src.core.game3.bag')
local Items = require('src.core.game3.items_data')
local Use = require('src.core.game3.item_use')
local Pokemon = require('src.core.game3.pokemon')

function M.copy(value)
  if type(value) ~= 'table' then return value end
  local out = {}; for k,v in pairs(value) do out[k] = M.copy(v) end; return out
end
function M.same(a,b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= 'table' then return a == b end
  for k,v in pairs(a) do if not M.same(v,b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
function M.status(mon)
  local st = mon.status
  if st and st ~= 0 and st ~= '' and st ~= '0' then return tostring(st) end
  return (tonumber(mon.sleep) or 0)>0 and 'SLP' or nil
end
function M.usable(mon)
  return mon and not Pokemon.isEgg(mon) and not mon.badEgg and not mon.isBadEgg
    and (tonumber(mon.maxHp or mon.maxhp) or 0)>0
end
function M.name(mon) return Pokemon.displayMonName(mon) end

-- Ordinary shop medicine only. No berries, bitter herbs, PP items or Sacred Ash.
local IDS = {13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29}
local PREMIUM = {[19]=true,[20]=true,[25]=true}
local CURES = {[14]=true,[15]=true,[16]=true,[17]=true,[18]=true,[23]=true}
local HEALS = {[13]=true,[19]=true,[20]=true,[21]=true,[22]=true,[26]=true,[27]=true,[28]=true,[29]=true}
function M.effect(mon,id)
  if not M.usable(mon) then return false end
  if id==24 or id==25 then return Use.revive(mon,id==25) end
  if (tonumber(mon.hp) or 0)<=0 then return false end
  if CURES[id] then return Use.clearStatus(mon,id) end
  if HEALS[id] then return Use.healMon(nil,mon,id) end
  return false
end

function M.plan(session, options, onlySlot)
  options = options or {}
  local plan = {steps={}, totals={}, beforeParty=M.copy(session.party or {}),
    beforeBag=M.copy(session.bag or {}), refs={}, after={}, remaining=0, slot=onlySlot}
  local bag = M.copy(session.bag or {})
  local stock = {}
  for _,id in ipairs(IDS) do
    stock[id] = (not PREMIUM[id] or options.premium) and Bag.get(bag,id) or 0
  end
  for slot, original in ipairs(session.party or {}) do
    plan.refs[slot] = original
    local mon = M.copy(original)
    plan.after[slot] = mon
    if M.usable(mon) and (not onlySlot or onlySlot==slot) then
      local function spend(id)
        local before = M.copy(mon)
        if not M.effect(mon,id) then return false end
        stock[id] = stock[id]-1
        plan.steps[#plan.steps+1] = {slot=slot,id=id,before=before,after=M.copy(mon)}
        plan.totals[id] = (plan.totals[id] or 0)+1
        return true
      end
      if mon.hp<=0 and options.revive~=false then
        if stock[24]>0 then spend(24) elseif stock[25]>0 then spend(25) end
      end
      if mon.hp>0 and options.cure~=false and M.status(mon) then
        -- Full Restore earns its premium cost only when it can do both jobs.
        if stock[19]>0 and mon.hp<(mon.maxHp or mon.maxhp) then spend(19)
        else
          for _,id in ipairs({14,15,16,17,18,23,19}) do
            if stock[id]>0 and M.effect(M.copy(mon),id) then spend(id); break end
          end
        end
      end
      local limit=0
      while mon.hp>0 and mon.hp<(mon.maxHp or mon.maxhp) do
        local best, score
        for _,id in ipairs(IDS) do
          -- A Full Restore would also cure status; respect the cure toggle.
          if HEALS[id] and stock[id]>0 and not (id==19 and options.cure==false and M.status(mon)) then
            local candidate=M.copy(mon)
            if M.effect(candidate,id) then
              local missing=(mon.maxHp or mon.maxhp)-mon.hp
              local amount=Items.HEAL_AMOUNT[id] or 9999
              local n=amount>=missing and (amount-missing) or (100000-amount)
              if not score or n<score then best,score=id,n end
            end
          end
        end
        if not best then break end
        spend(best); limit=limit+1
        if limit>=1000 then break end
      end
      if mon.hp<(mon.maxHp or mon.maxhp) or M.status(mon) then plan.remaining=plan.remaining+1 end
    end
  end
  return plan
end

function M.apply(session, plan, ready)
  local ok,why = ready()
  if not ok then return false,why,0 end
  if plan.applied then return false,'This preview has already been used.',0 end
  if not M.same(session.party or {},plan.beforeParty) or not M.same(session.bag or {},plan.beforeBag) then
    return false,'Party or Bag changed. Make a fresh preview.',0
  end
  for slot,mon in pairs(plan.refs) do
    if session.party[slot]~=mon then return false,'Party changed. Make a fresh preview.',0 end
  end
  -- Mark before mutation so a confirmation can never spend twice.
  plan.applied=true
  local used=0
  for _,step in ipairs(plan.steps) do
    local mon=session.party[step.slot]
    if mon~=plan.refs[step.slot] or not M.same(mon,step.before) or Bag.get(session.bag,step.id)<1 then
      return false,'State changed. Stopped after '..used..' item(s). Review the party.',used
    end
    -- Normal field routine handles consumption, status and the native quest log.
    local stock=Bag.get(session.bag,step.id)
    local called,success=pcall(Use.useField,session,session.bag,step.id,step.slot)
    if not called then return false,'Item processing failed. Review party and Bag before retrying.',used end
    if not success then return false,'An item was refused. Stopped after '..used..' item(s).',used end
    used=used+1
    if not M.same(mon,step.after) or Bag.get(session.bag,step.id)~=stock-1 then
      return false,'An item effect changed. Stopped after '..used..' item(s). Review the party.',used
    end
  end
  return true,used..' item(s) used. '..plan.remaining..' Pokemon still need care.',used
end
return M
