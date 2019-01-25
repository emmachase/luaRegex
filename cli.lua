#!/usr/bin/env lua
-- Command Line Interface to luaRegex

local r2l = require("r2l")
local getopt = require("getopt")
local term = require("termutils")

local pprint = require("pprint")

local parser = require("parser")

local helpStr = [[
%{cyan}Syntax: %{white}./cli.lua [OPTIONS] <regex>
  OPTIONS:
    -h : Display this help message

    -o <outputFile> : Redirect output to a file instead of stdout

    -l : Stop after lex stage
    -p : Stop after parse stage

  <regex>: The regex source as a string
]]

local function printHelp()
  print(term.ansi(helpStr))
end

local stopStage = "none"

local regexSrc
local outputFile = io.stdout
getopt({...}, "-o:hlp", {
  help = {
    hasArg = getopt.noArgument,
    val = "h"
  }
}) {
  [1] = function(val) -- Non option
    if regexSrc then
      term.printError("More than one regex provided (perhaps forgot to enclose with \"\"?)")
      os.exit()
    end

    regexSrc = val
  end,
  o = function(fileName)
    outputFile = io.open(fileName, "w")
    if not outputFile then
      term.printError("Unable to open file '" .. fileName .. "' for writing")
      os.exit()
    end
  end,
  h = function()
    printHelp()
    os.exit()
  end,
  l = function()
    stopStage = "lex"
  end,
  p = function()
    stopStage = "parse"
  end
}

if not regexSrc then
  term.printError("Invalid Syntax.")
  return printHelp()
end

local tokens = parser.lexRegex(regexSrc)
if stopStage == "lex" then
  pprint(tokens)

  return
end

local parsedRegex = parser.parse(tokens)
if stopStage == "parse" then
  pprint(parsedRegex)

  return
end
