-- Main utilty file, exposes entire library

local pprint = require("pprint")

local r2l = {}
r2l.parser = require("parser")

local util = require("util")

r2l.epsilon = {type = "epsilon"} -- Special value for epsilon transition
r2l.any = {type = "any"}

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

  local machine
  if capture.type == "char" then
    local sName, cName = genName(), genName()
    machine = {
      states = {
        [sName] = {edges = {{condition = capture.value, dest = cName}}},
        [cName] = {edges = {}}
      },
      startState = sName,
      acceptStates = {[cName] = true}
    }
  elseif capture.type == "any" then
    local sName, cName = genName(), genName()
    machine = {
      states = {
        [sName] = {edges = {{condition = r2l.any, dest = cName}}},
        [cName] = {edges = {}}
      },
      startState = sName,
      acceptStates = {[cName] = true}
    }
  elseif capture.type == "set" then
    local sName, cName = genName(), genName()
    machine = {
      states = {
        [sName] = {edges = {}},
        [cName] = {edges = {}}
      },
      startState = sName,
      acceptStates = {[cName] = true}
    }

    local tState = machine.states[sName]
    for i = 1, #capture do
      local match = capture[i]
      if match.type == "char" then
        tState[#tState + 1] = {condition = match.value, dest = cName}
      elseif match.type == "range" then
        local dir = match.finish:byte() - match.start:byte()
        dir = dir / math.abs(dir)

        for j = match.start:byte(), match.finish:byte(), dir do
          tState[#tState + 1] = {condition = string.char(j), dest = cName}
        end
      end
    end
  else
    error("Unimplemented capture: '" .. capture.type .. "'")
  end

  if atom.type == "atom" then
    return machine
  elseif atom.type == "plus" then
    for k in pairs(machine.acceptStates) do
      local es = machine.states[k].edges
      es[#es + 1] = {condition = r2l.epsilon, dest = machine.startState}
    end

    return machine
  elseif atom.type == "ng-plus" then
    for k in pairs(machine.acceptStates) do
      local es = machine.states[k].edges
      es[#es + 1] = {condition = r2l.epsilon, priority = "low", dest = machine.startState}
    end

    return machine
  elseif atom.type == "star" then
    local needStart = true
    for k in pairs(machine.acceptStates) do
      local es = machine.states[k].edges
      es[#es + 1] = {condition = r2l.epsilon, dest = machine.startState}
      if k == machine.startState then
        needStart = false
      end
    end

    if needStart then
      machine.acceptStates[machine.startState] = true
    end

    return machine
  elseif atom.type == "ng-star" then
    local needStart = true
    for k in pairs(machine.acceptStates) do
      local es = machine.states[k].edges
      es[#es + 1] = {condition = r2l.epsilon, priority = "low", dest = machine.startState}
      if k == machine.startState then
        needStart = false
      end
    end

    if needStart then
      machine.acceptStates[machine.startState] = true
    end

    return machine
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
