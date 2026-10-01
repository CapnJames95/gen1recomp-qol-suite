local M={}
local Catch=require('src.core.game3.battle.catching')
local Pokemon=require('src.core.game3.pokemon')
local Items=require('src.core.game3.items_data')
local Bag=require('src.core.game3.bag')
function M.copy(value)
  if type(value)~='table' then return value end
  local out={};for k,v in pairs(value) do out[k]=M.copy(v) end;return out
end
function M.supported(st)
  return st and st.wild and st.enemy and st.enemy.mon and (tonumber(st.enemy.mon.hp) or 0)>0
    and not st.double and not st.link and not st.spectate and not st.safari
    and not st.oldManTutorial and not st.pokedude and not st.ghostBattle
end
function M.probability(odds)
  if odds>=255 then return 1 end
  if odds<=0 then return 0 end
  local threshold=math.floor(1048560/math.sqrt(math.sqrt(16711680/odds)))
  return math.min(1,(threshold/65536)^4)
end
function M.percent(p)
  if p>=1 then return '100%' end
  if p>0.999 then return '>99.9%' end
  if p>0 and p<0.001 then return '<0.1%' end
  return ('%.1f%%'):format(p*100)
end

local RISK_MOVES={
  [120]='Self-Destruct can make the foe faint.',[153]='Explosion can make the foe faint.',
  [100]='Teleport can end the encounter.',[46]='Roar can end the encounter.',[18]='Whirlwind can end the encounter.',
  [36]='Take Down can cause recoil.',[38]='Double-Edge can cause recoil.',[66]='Submission can cause recoil.',
  [344]='Volt Tackle can cause recoil.',[165]='Struggle causes recoil.',
  [174]='Curse can cost the user HP.',[195]='Perish Song can start a fainting countdown.',
  [262]='Memento makes the user faint.',
}
function M.snapshot(session,st)
  if not M.supported(st) then return nil,'Use R at an ordinary wild single-battle command menu.' end
  local foe=st.enemy
  local species=foe.species or foe.mon.species
  local meta=Pokemon.speciesMeta(species)
  if not meta or not tonumber(meta.catchRate) then return nil,'Catch data is unavailable for this species.' end
  local out={name=Pokemon.name(species),hp=foe.mon.hp,maxHp=foe.mon.maxHp,balls={},risks={},
    status=foe.status or foe.mon.status or 'OK',turn=st.turn or st.turnCount or 1,
    modified=require('src.mods.Runtime').wantsHook('catch.rate')}
  -- Bag.get normalises pockets; read a copy so browsing never rewrites inventory.
  local bag=M.copy(session.bag or {})
  local low=M.copy(foe);low.mon.hp=1
  local asleep=M.copy(low);asleep.status='SLP';asleep.mon.status='SLP'
  for id=1,12 do
    local count=Bag.get(bag,id)
    if id~=5 and count>0 then
      local row={id=id,name=Items.displayName(id),count=count,mult=Catch.ballMultiplier(id,foe,st,session)/10,
        chance=M.probability(Catch.catchOdds(id,foe,st,session)),
        low=M.probability(Catch.catchOdds(id,low,st,session)),
        sleep=M.probability(Catch.catchOdds(id,asleep,st,session))}
      out.balls[#out.balls+1]=row
    end
  end
  table.sort(out.balls,function(a,b)
    if a.id==1 or b.id==1 then return b.id==1 end -- conserve Master Balls
    if a.chance~=b.chance then return a.chance>b.chance end
    return a.id<b.id
  end)
  for _,row in ipairs(out.balls) do if row.id~=1 then out.best=row;break end end
  local function risk(text) out.risks[#out.risks+1]=text end
  if st.roamer then risk('Roaming Pokemon may flee.') end
  local status=tostring(out.status):upper()
  if status=='PSN' or status=='TOX' or status=='BRN' or status=='POISON' or status=='BURN' then
    risk('Poison / burn can cause the foe to faint between throws.')
  end
  if (foe.confusionTurns or 0)>0 then risk('Confusion may cause self-damage.') end
  if st.weather and st.weather~='none' and st.weather~=0 then risk('Weather is active. Check whether it damages this foe.') end
  local seen,hasPp={},false
  for slot=1,4 do
    local id=Pokemon.moveIdAt(foe.mon,slot)
    local pp=tonumber(foe.mon.pp and foe.mon.pp[slot])
    if id and id~=0 and (pp==nil or pp>0) then
      hasPp=true
      if RISK_MOVES[id] and not seen[id] then risk(RISK_MOVES[id]);seen[id]=true end
    end
  end
  if not hasPp then risk('No usable PP detected: Struggle recoil is a risk.') end
  if #out.risks==0 then risk('No listed risk detected. This is not a guarantee of safety.') end
  risk('Moveset warnings inspect current moves, even before they are used. Abilities and move failure can prevent an effect.')
  risk('Damage, escape and next-turn actions are not predicted. Residual effects are not exhaustively modelled.')
  return out
end
return M
