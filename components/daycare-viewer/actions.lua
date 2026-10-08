return function(Travel)
  local A={}
  local Runtime=require('src.core.game3.runtime')
  local D=require('src.core.game3.daycare')
  local P=require('src.core.game3.pokemon')
  local Scripts=require('src.core.game3.scripting.stdscripts')
  local Std=Scripts.SPECIAL
  local Native=require('src.core.game3.scripting.natives_daycare').BY_NAME
  local Queries=require('src.core.game3.scripting.natives_queries').BY_NAME
  local function context(slot,cost)
    return {specialVars={[0x8004]=(slot or 1)-1,[0x8005]=cost or 0},stringVars={}}
  end
  local function query(name,ctx) local _,value=Queries[name](ctx);return value end
  local function ready(session,site)
    if Runtime.getSession()~=session then return false,'The playthrough changed. Reopen DAY CARE.' end
    if require('src.core.game3.profile').forSession(session).family=='rse' and site~='four' then return false,'Hoenn has one Day Care, on Route 117.' end
    if site~='route5' and site~='four' then return false,'Unknown Day Care.' end
    return Travel.ready()
  end
  local function state(session,site)
    local root=session.modData and session.modData[D.SAVE_KEY] or {}
    return rawget(session,site=='four' and 'daycare' or 'route5Daycare') or root[site=='four' and 'daycare' or 'route5Daycare'] or {}
  end
  function A.mon(session,site,slot)
    local dc=state(session,site)
    return site=='four' and D.mon(dc,slot) or (site=='route5' and dc.mon or nil)
  end
  function A.quote(session,site,slot)
    local dc=state(session,site);local mon=A.mon(session,site,slot)
    if not mon or D.speciesOf(mon)==0 then return nil end
    local steps=site=='four' and (dc.steps or {})[slot] or dc.steps
    return {mon=mon,cost=D.cost(mon,steps),steps=tonumber(steps) or 0}
  end
  local function pending(session,site)
    return site=='four' and D.isEggPending(state(session,site))
  end
  function A.deposit(session,site,slot,expected)
    local ok,why=ready(session,site);if not ok then return false,why end
    local mon=session.party and session.party[slot]
    if not mon or mon~=expected or D.speciesOf(mon)==0 then return false,'Party changed. Choose the Pokemon again.' end
    if P.isEgg(mon) or mon.isBadEgg then return false,'Eggs cannot be deposited.' end
    if pending(session,site) then return false,require('src.core.game3.profile').forSession(session).family=='rse' and 'Collect the waiting egg at Route 117 first.' or 'Collect the waiting egg at Four Island first.' end
    local dc=state(session,site)
    if (site=='four' and not D.findEmptySpot(dc)) or (site=='route5' and dc.mon) then return false,'This Day Care is full. Withdraw a Pokemon first.' end
    local ctx=context(slot)
    if query('CountPartyNonEggMons',ctx)<=1 or query('CountPartyAliveNonEggMons_IgnoreVar0x8004Slot',ctx)==0 then
      return false,'Keep another usable, non-Egg Pokemon in your party.'
    end
    Native[site=='four' and 'StoreSelectedPokemonInDaycare' or 'PutMonInRoute5Daycare'](ctx)
    -- The native daycare scripts increment GAME_STAT_USED_DAYCARE (47).
    require('src.core.game3.scripting.ops_a').dispatchUnhooked({ctx=ctx},{op='incrementgamestat',[1]=47})
    return true,'Pokemon deposited. Save your game normally.'
  end
  function A.withdraw(session,site,slot,expected)
    local ok,why=ready(session,site);if not ok then return false,why end
    local quote=A.quote(session,site,slot)
    if not quote or not expected or quote.mon~=expected.mon or quote.cost~=expected.cost or quote.steps~=expected.steps then
      return false,'Day Care changed. Review the Pokemon and fee again.'
    end
    if pending(session,site) then return false,require('src.core.game3.profile').forSession(session).family=='rse' and 'Collect the waiting egg at Route 117 first.' or 'Collect the waiting egg at Four Island first.' end
    local ctx=context(slot,quote.cost)
    if query('CalculatePlayerPartyCount',ctx)>=6 then return false,'Your party is full. Make room before withdrawing.' end
    if query('IsEnoughForCostInVar0x8005',ctx)~=1 then return false,'Not enough money. The fee is $'..quote.cost..'.' end
    local _,species=Native[site=='four' and 'TakePokemonFromDaycare' or 'TakePokemonFromRoute5Daycare'](ctx)
    if not species or species==0 then return false,'The game could not withdraw this Pokemon.' end
    Queries.SubtractMoneyFromVar0x8005(ctx)
    return true,'Pokemon withdrawn for $'..quote.cost..'. Save your game normally.'
  end
  function A.teleport(session,site)
    local ok,why=ready(session,site);if not ok then return false,why end
    local destination=require('src.core.game3.profile').forSession(session).family=='rse' and {map=require('src.core.game3.profile').forSession(session).map.enginePrefix..'ROUTE117_POKEMON_DAY_CARE',x=2,y=4,facing='up'} or site=='four' and {map='FourIsland_PokemonDayCare',x=2,y=4,facing='up'}
      or {map='Route5_PokemonDayCare',x=4,y=5,facing='up'}
    local point;point,why=Travel.destination(destination)
    if not point then return false,why end
    return Travel.warp(point)
  end
  return A
end
