--[[
MIT License

Copyright (c) 2019 emmachase

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local api = {}

local term = require("termutils")

api.noArgument = 0
api.requiredArgument = 1
api.optionalArgument = 2

api.notOpt = {}

--[[
longOpts format:
{
  name = {
    hasArg = 0|1|2,
    val = <something>
  }...
}

config:
{
  printErrors = true,
  noErrors = not printErrors
}
]]
function api.getopt(argTbl, optString, longOpts, config)
  config = config or {}

  local printErrors = true
  if config.printErrors == false or (not config.noErrors) then
    printErrors = false
  end
  longOpts = longOpts or {}

  local toParse = {}
  for i = 1, #argTbl do
    toParse[i] = argTbl[i]
  end

  local parseMode
  local shortOpts = {}
  parseMode, optString = optString:match("^([-+]?)(.*)")
  while #optString > 0 do
    local char, args
    char, args, optString = optString:match("^(.)([:]?[:]?)(.*)")

    if not char then
      term.printError("Malformed optString", 2)
      os.exit()
    end

    shortOpts[char] = {
      hasArg = (args == ":" and api.requiredArgument) or
               (args == "::" and api.optionalArgument) or api.noArgument
    }
  end

  local instance = {}
  instance.notOptions = {}

  function instance.evalNext()
    local opt = table.remove(toParse, 1)

    if opt == "--" then
      return -1
    end

    if opt:sub(1, 1) == "-" then
      if opt:sub(2, 2) == "-" then
        -- Long option
        opt = opt:sub(3)

        local optParams = longOpts[opt]
        if optParams then
          if optParams.hasArg == api.noArgument then
            return optParams.val or opt, nil
          else
            local nextElm = toParse[1]

            if optParams.hasArg == api.optionalArgument then
              if nextElm:sub(1, 1) == "-" then
                return optParams.val or opt, nil
              else
                table.remove(toParse, 1)
                return optParams.val or opt, nextElm
              end
            elseif optParams.hasArg == api.requiredArgument then
              if (not nextElm) or nextElm:sub(1, 1) == "-" then
                term.printError(("Option '--%s' requires an argument"):format(opt), 0)
                os.exit()
              else
                table.remove(toParse, 1)
                return optParams.val or opt, nextElm
              end
            else
              term.printError(("Option Parameter 'hasArg' for '--%s' is invalid"):format(opt), 0)
              os.exit()
            end
          end
        else
          if printErrors then
            print(("Unknown option '--%s'"):format(opt), 8)
            os.exit()
          end

          return "?", opt
        end
      else
        if opt == "-" then
          return api.notOpt
        end

        -- Short option
        opt = opt:sub(2)

        local char
        char, opt = opt:match("^(.)(.*)")

        table.insert(toParse, 1, "-" .. opt)

        local optParams = shortOpts[char]
        if optParams then
          if optParams.hasArg == api.noArgument then
            return char, nil
          else
            local nextElm = toParse[2]
            if optParams.hasArg == api.optionalArgument then
              if #opt == 0 then
                if nextElm:sub(1, 1) == "-" then
                  return char, nil
                else
                  table.remove(toParse, 2)
                  return char, nextElm
                end
              else
                return char, nil
              end
            elseif optParams.hasArg == api.requiredArgument then
              if #opt == 0 then
                if (not nextElm) or nextElm:sub(1, 1) == "-" then
                  term.printError(("Option '-%s' requires an argument"):format(char), 0)
                  os.exit()
                else
                  table.remove(toParse, 2)
                  return char, nextElm
                end
              else
                local arg = opt
                table.remove(toParse, 1)

                return char, arg
              end
            else
              term.printError(("Option Parameter 'hasArg' for '--%s' is invalid"):format(opt), 0)
              os.exit()
            end
          end
        else
          if printErrors then
            print(("Unknown option '-%s'"):format(char), 8)
            os.exit()
          end

          return "?", char
        end
      end
    else
      if parseMode == "+" then
        return -1, opt
      elseif parseMode == "-" then
        return 1, opt
      else
        instance.notOptions[#instance.notOptions + 1] = opt
        return api.notOpt
      end
    end
  end

  setmetatable(instance, {
    __call = function(self, switchTable)
      local val, arg = 0
      while #toParse > 0 and val ~= -1 do
        val, arg = instance.evalNext()
        if val ~= api.notOpt then
          if switchTable[val] then
            switchTable[val](arg)
          elseif switchTable.default then
            switchTable.default(val, arg)
          end
        end
      end

      for i = 1, #toParse do
        instance.notOptions[#instance.notOptions + 1] = toParse[i]
      end

      return instance
    end
  })

  return instance
end

setmetatable(api, {__call = function(self, ...) return api.getopt(...) end})
return api
