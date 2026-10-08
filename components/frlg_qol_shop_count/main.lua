return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local Shop = require("src.ui.game3.shop_menu")
  local Bag = require("src.core.game3.bag")
  Shop._frlgQolOwnedCount = function(id)
    local session = Shop._session
    if api.active() and session and session.bag and id and (not Shop._martType or Shop._martType=='NORMAL') then return Bag.get(session.bag, id) end
  end
  api.wrap(Shop, "draw", function(previous, ...)
    local result = previous(...)
    local session=Shop._session
    local emerald=session and require("src.core.game3.profile").forSession(session).family=="rse"
    if Shop.open and (not Shop._martType or Shop._martType=='NORMAL') and (emerald and Shop.state=='list' or not emerald and Shop.mode=='buy') and not Shop._fading then
      local index=emerald and ((Shop.scroll or 0)+(Shop.row or 0)+1) or Shop.cursor
      local raw = (Shop._items or {})[index]
      local id = type(raw) == "table" and (raw.id or raw.itemId or raw.item) or raw
      local session = Shop._session
      if id and session and session.bag then
        local y=emerald and 40 or 56
        api.frame(1, emerald and 5 or 7, 9, emerald and 2 or 3)
        love.graphics.setColor(0.82, 0.91, 0.96, 1)
        love.graphics.rectangle("fill", 9, y, 70, emerald and 16 or 24)
        love.graphics.setColor(1, 1, 1, 1)
        api.text("OWNED " .. Bag.get(session.bag, id), 12, y+4, 64, true)
      end
    end
    return result
  end)
end
