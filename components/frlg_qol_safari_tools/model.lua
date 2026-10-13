local M={}
function M.data(s)
 s.modData=s.modData or {};s.modData.safari_tools=s.modData.safari_tools or {};return s.modData.safari_tools
end
function M.allowances(s,steps,balls)
 local Safari=require('src.core.game3.safari');local cfg=Safari.rseConfig(s)
 local baseSteps=cfg and cfg.steps or Safari.STEPS;local baseBalls=cfg and cfg.balls or Safari.BALLS
 return baseSteps*((steps==2 or steps==5) and steps or 1),(balls==50 or balls==99) and balls or baseBalls
end
function M.refill(s,steps,balls)
 if not require('src.core.game3.safari').isActive(s)then return false,'Enter a Safari game first.' end
 local a,b=M.allowances(s,steps,balls);s.safari.steps=a;s.safari.balls=b
 local Battle=require('src.core.game3.battle');local st=Battle.getState()
 if Battle.isActive() and st and st.safari and st.safariState then st.safariState.balls=b end
 M.data(s).pending=nil;M.data(s).retire=nil;return true
end
function M.status(s,steps,balls)
 local Safari=require('src.core.game3.safari');if not s or not Safari.isActive(s)then return 'Safari: inactive' end
 local pending=M.data(s).pending
 return 'Steps: '..(steps==0 and 'INF' or tostring(pending=='steps' and 0 or s.safari.steps))..' / Balls: '..(balls==0 and 'INF' or tostring(pending=='balls' and 0 or s.safari.balls))
end
return M
