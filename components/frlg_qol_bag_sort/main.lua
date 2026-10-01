return function(mod)
  local Support = assert(load(assert(mod:read("support.lua")), "@" .. mod.path .. "/support.lua"))()
  mod.options:define({ { key = "enabled", label = "ENABLED", type = "toggle", default = true } })
  local api = Support.new(mod)
  local BagMenu = require("src.ui.game3.bag_menu")
  mod.options:define({
    { key = "enabled", label = "ENABLED", type = "toggle", default = true },
    { key = "sort", label = "SORT", type = "choice", default = "name",
      choices = { { "NAME", "name" }, { "QUANTITY", "quantity" }, { "ITEM ID", "id" } } },
  })
  api.wrap(BagMenu, "list", function(previous, ...)
    local rows = previous(...)
    local out = {}
    for index, row in ipairs(rows) do out[index] = row end
    table.sort(out, function(left, right)
      local mode = mod.options:get("sort")
      if mode == "quantity" and left.qty ~= right.qty then return left.qty > right.qty end
      if mode == "id" then return left.id < right.id end
      local lname, rname = tostring(left.name):upper(), tostring(right.name):upper()
      if lname ~= rname then return lname < rname end
      return left.id < right.id
    end)
    return out
  end)
end
