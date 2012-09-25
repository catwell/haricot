
--- Class

local methods = {
}

local new = function()
  return setmetatable({},{__index = methods})
end

return {
  new = new,
}
