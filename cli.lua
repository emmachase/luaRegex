#!/usr/bin/env luajit
-- Command Line Interface to luaRegex

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

local r2l = require("r2l")

local getopt = require("getopt")
local term = require("termutils")

local pprint = require("pprint")

local helpStr = [[
%{cyan}Syntax: %{white}./cli.lua [OPTIONS] <regex>
  <regex>: The regex source as a string

  OPTIONS:
    -h : Display this help message

    -o <outputFile> : Redirect output to a file instead of stdout

    -l : Stop after lex stage
    -p : Stop after parse stage
    -g : Stop after initial generation (unoptimised, so very large output)
    -r : Stop after reducing the naiive NFA to DFA
]]

local function printHelp()
  print(term.ansi(helpStr))
end

local stopStage = "none"

local regexSrc
local outputFile = io.stdout
getopt({...}, "-o:hlpgr", {
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
  end,
  g = function()
    stopStage = "igen"
  end,
  r = function()
    stopStage = "dfa"
  end
}

if not regexSrc then
  term.printError("Invalid Syntax.")
  return printHelp()
end

if regexSrc == "" then
  term.printError("Regex cannot be empty.")
  return printHelp()
end

local tokens = r2l.parser.lexRegex(regexSrc)
if stopStage == "lex" then
  return pprint(tokens) end

local parseSuccess, parsedRegex = pcall(r2l.parser.parse, tokens)
if not parseSuccess then
  return term.printError("Parse Error: %{white}" .. parsedRegex .. "\n%{cyan}Aborting...") end

if stopStage == "parse" then
  return pprint(parsedRegex) end

local origNFA = r2l.nfactory.generateNFA(parsedRegex)
if stopStage == "igen" then
  return pprint(origNFA) end

local origDFA = r2l.reducer.reduceNFA(origNFA)
if stopStage == "dfa" then
  return pprint(origDFA) end

outputFile:write(r2l.emitter.generateLua(origDFA))
outputFile:close()
