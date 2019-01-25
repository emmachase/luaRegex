local util = {}

function util.deepClone(tab)
  local nt = {}

  for k, v in pairs(tab) do
    if type(v) == "table" then
      nt[k] = util.deepClone(v)
    else
      nt[k] = v
    end
  end

  return nt
end

return util
