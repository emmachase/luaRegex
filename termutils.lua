local termutils = {}

local ansi = require("ansicolors")
termutils.ansi = ansi

function termutils.printError(err)
  print(ansi("%{red}"..err) .. "\n")
end

return termutils