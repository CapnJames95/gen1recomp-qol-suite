local M = {}
local D = require('src.core.game3.daycare')
local B = require('src.core.game3.breeding')
local P = require('src.core.game3.pokemon')
local E = require('src.core.game3.battle.experience')
local S = require('src.core.game3.summary_data')
local I = require('src.core.game3.items_data')
local groups = {'Monster','Water 1','Bug','Flying','Field','Fairy','Grass','Human-Like','Water 3','Mineral','Amorphous','Water 2','Ditto','Dragon','Undiscovered'}
function M.copy(value)
  if type(value) ~= 'table' then return value end
  local out = {}; for k,v in pairs(value) do out[k] = M.copy(v) end; return out
end
-- stateOf/route5Of normalize and write to the save. Inspect the same stores
-- without calling those mutators, including pre-normalization session aliases.
local function store(session, key)
  local root = session.modData and session.modData[D.SAVE_KEY]
  return M.copy(rawget(session,key) or (root and root[key]) or {})
end
local function valid(mon) return mon and D.speciesOf(mon) > 0 end
local function moves(mon)
  local out = {}
  for i=1,4 do
    local id = mon.moves and mon.moves[i] or 0
    if type(id)=='table' then id=id.id or id.move end
    out[i] = (tonumber(id) or 0)>0 and P.moveName(tonumber(id)) or '--'
  end
  return out
end
function M.mon(mon, steps, mail)
  if not valid(mon) then return nil end
  mon = M.copy(mon); steps = tonumber(steps) or 0
  local preview = M.copy(mon)
  -- Experience.apply emits pokemon.level_up to other mods even for a copy.
  -- Project the native calculation without gameplay events or RNG calls.
  if (tonumber(preview.level) or 1) < 100 then
    local from = tonumber(preview.level) or 1
    E.syncExpToLevel(preview)
    preview.exp = math.min(preview.exp + math.max(0, math.floor(steps)), E.expForLevel(preview, 100))
    preview.level = E.levelForExp(preview, preview.exp)
    for level = from + 1, preview.level do
      for _, move in ipairs(P.movesLearnedAt(D.speciesOf(preview), level) or {}) do D.teachMove(preview, move) end
    end
  end
  P.applyStats(preview)
  local growth = E.growthRate(mon)
  local exp = tonumber(mon.exp) or E.expForLevel(growth, mon.level or 1)
  local level = D.levelAfterSteps(mon, steps)
  local eggGroups = B.eggGroups(D.speciesOf(mon))
  local names = {groups[eggGroups[1]] or '?'}
  if eggGroups[2] ~= eggGroups[1] then names[#names+1] = groups[eggGroups[2]] or '?' end
  local item = mon.item or mon.heldItem or 0
  return {raw=mon, preview=preview, name=D.nickname(mon), species=P.name(D.speciesOf(mon)),
    level=level, before=E.levelForExp(growth,exp), gained=D.levelsGained(mon,steps),
    steps=steps, cost=D.cost(mon,steps), exp=math.min(exp+steps,E.expForLevel(growth,100)),
    nextLevel=level<100 and math.max(0,E.expForLevel(growth,level+1)-exp-steps) or nil,
    nature=select(2,S.nature(mon)), gender=P.gender(D.speciesOf(mon),mon.personality),
    shiny=P.isShiny(mon), ability=P.abilityName(mon.ability or P.abilityId(D.speciesOf(mon),mon.personality)),
    item=(item==0 or item=='NONE') and 'None' or I.displayName(item),
    groups=table.concat(names,' / '), mail=mail~=nil, moves=moves(mon), afterMoves=moves(preview)}
end
function M.snapshot(session)
  local dc, r5 = store(session,'daycare'), store(session,'route5Daycare')
  dc.steps=dc.steps or {0,0}
  local out={parents={}, route5=M.mon(r5.mon,r5.steps,r5.mail), pending=D.isEggPending(dc), eggs={}, total=0}
  for i=1,2 do
    out.parents[i]=M.mon(D.mon(dc,i),dc.steps[i],dc.mail and dc.mail[i])
    if out.parents[i] then out.total=out.total+out.parents[i].cost end
  end
  out.count=(out.parents[1] and 1 or 0)+(out.parents[2] and 1 or 0)
  out.compatibility=out.count==2 and B.compatibility(dc) or 0
  if out.count<2 then out.reason='Two deposited parents are needed.'
  elseif out.compatibility==0 then
    local a,b=out.parents[1],out.parents[2]
    local ga,gb=B.eggGroups(D.speciesOf(a.raw)),B.eggGroups(D.speciesOf(b.raw))
    if ga[1]==15 or gb[1]==15 then out.reason='An Undiscovered parent cannot breed.'
    elseif ga[1]==13 and gb[1]==13 then out.reason='Two Ditto cannot breed together.'
    elseif a.gender=='U' or b.gender=='U' then out.reason='Genderless parents need Ditto.'
    elseif a.gender==b.gender then out.reason='Parents have the same gender.'
    else out.reason='Parents share no egg group.' end
  else
    out.reason=({[20]='The pair is not very compatible.',[50]='The pair gets along.',[70]='The pair gets along very well.'})[out.compatibility]
    -- tryProduceEgg runs AFTER incrementing slot 2; a check at 255 that
    -- already failed is followed by a full 256 steps, never zero steps.
    out.nextCheck=(254-(tonumber(dc.steps[2]) or 0))%256+1
  end
  if out.count==2 and (out.compatibility>0 or out.pending) then
    local variants={}
    for _,pid in ipairs(out.pending and {tonumber(dc.offspringPersonality) or 0} or {0,32768}) do
      local copy=M.copy(dc); copy.offspringPersonality=pid
      local species=B.alterEggSpeciesWithIncenseItem(B.parentSlots(copy),copy)
      local name=P.name(species)
      if variants[1]~=name then variants[#variants+1]=name end
    end
    out.offspring=table.concat(variants,' / ')
  end
  out.hatchRate=session.version=='emerald' and D.eggCyclesToSubtract(session) or 1
  out.hatchCheck=(254-(tonumber(dc.stepCounter) or 0))%256+1
  for i=1,6 do
    local mon=session.party and session.party[i]
    if mon and P.isEgg(mon) then
      local cycles=tonumber(mon.friendship or mon.eggCycles or mon.cycles) or 20
      out.eggs[#out.eggs+1]={slot=i, cycles=cycles, bad=mon.isBadEgg,
        steps=out.hatchCheck+math.ceil(math.max(0,cycles)/out.hatchRate)*256}
    end
  end
  return out
end
return M
