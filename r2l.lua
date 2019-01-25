-- Main utilty file, exposes entire library

local pprint = require("pprint")

local r2l = {}
r2l.parser = require("parser")

local util = require("util")

r2l.epsilon = {type = "epsilon"} -- Special value for epsilon transition

local nameCounter = 0
local function genName()
  nameCounter = nameCounter + 1
  return "s" .. nameCounter
end

local function emptyMachine(noAccept)
  local sName = genName()
  local machine = {
    states = {
      [sName] = {edges = {}}
    },
    startState = sName,
    acceptStates = {[sName] = true}
  }

  if noAccept then
    machine.acceptStates = {}
  end

  return machine
end

function r2l.concatMachines(first, second)
  local newMachine = util.deepClone(first)

  for k, v in pairs(second.states) do
    newMachine.states[k] = v
  end

  for k in pairs(first.acceptStates) do
    local xs = newMachine.states[k].edges
    xs[#xs + 1] = {condition = r2l.epsilon, dest = second.startState}
  end

  newMachine.acceptStates = {}
  for k, v in pairs(second.acceptStates) do
    newMachine.acceptStates[k] = v
  end

  return newMachine
end

function r2l.unionMachines(first, second)
  local newMachine = util.deepClone(first)

  for k, v in pairs(second.states) do
    newMachine.states[k] = v
  end

  for k, v in pairs(second.acceptStates) do
    newMachine.acceptStates[k] = v
  end

  -- Link start state
  local xs = newMachine.states[newMachine.startState].edges
  xs[#xs + 1] = {condition = r2l.epsilon, dest = second.startState}

  return newMachine
end

function r2l.generateFromCapture(atom)
  local capture = atom[1]

  if capture.type == "char" then
    local sName, cName = genName(), genName()
    return {
      states = {
        [sName] = {edges = {{condition = capture.value, dest = cName}}},
        [cName] = {edges = {}}
      },
      startState = sName,
      acceptStates = {[cName] = true}
    }
  else
    error("Unimplemented capture: '" .. capture.type .. "'")
  end
end

function r2l.generateNFA(parsedRegex)
  local machine = emptyMachine(true)

  for i = 1, #parsedRegex do
    -- Different branches
    local branch = parsedRegex[i]
    local tempMachine = emptyMachine()

    for j = 1, #branch do
      local capture = branch[j]
      tempMachine = r2l.concatMachines(tempMachine, r2l.generateFromCapture(capture))
    end

    machine = r2l.unionMachines(machine, tempMachine)
  end

  return machine
end

return r2l
