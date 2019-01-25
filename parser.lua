-- Regex Parser
-- Parses to an internal IL representation used for the construction of an NFA

local parser = {}

function parser.lexRegex(regexStr)
  local termEaten
  local function peek()
    return regexStr:sub(1, 1)
  end

  local pos = 0
  local function eatc()
    local c = peek()
    termEaten = termEaten .. c
    regexStr = regexStr:sub(2)
    pos = pos + 1
    return c
  end

  local switchTable = {
    ["|"] = "union",
    ["*"] = function()
      if peek() == "?" then
        eatc()
        return "ng-star"
      end

      return "star"
    end,
    ["+"] = function()
      if peek() == "?" then
        eatc()
        return "ng-plus"
      end

      return "plus"
    end,
    ["("] = "l-paren",
    [")"] = "r-paren",
    ["."] = "any",
    ["^"] = "start",
    ["$"] = "eos",
    ["\\"] = function()
      local metas = {d = "[0-9]", w = "[a-zA-Z]", n = "\n"}

      local c = eatc()
      if metas[c] then

        regexStr = metas[c] .. regexStr
        pos = pos - #metas[c]

        return false
      end

      termEaten = termEaten:sub(2)
      return "char"
    end,
    ["["] = function()
      if peek() == "^" then
        eatc()
        return "open-negset"
      end

      return "open-set"
    end,
    ["]"] = "close-set",
    ["-"] = "range"
  }

  local tokens = {}
  while #regexStr > 0 do
    termEaten = ""
    local c = eatc()
    local lexFn = switchTable[c]
    local ret = "char"
    if lexFn then
      if type(lexFn) == "string" then
        ret = lexFn
      else
        ret = lexFn()
      end
    end

    if ret then
      tokens[#tokens + 1] = {
        type = ret,
        source = termEaten,
        position = pos
      }
    end
  end

  tokens[#tokens + 1] = {type = "eof", source = ""}

  return tokens
end

--[[

Grammar:

<RE>         ::= <simple-RE> <union-list>
<union-list> ::= "|" <simple-RE> <union-list> | <lambda>
<simple-RE>     ::= <basic-RE> <basic-RE-list>
<basic-RE-list> ::= <basic-RE> <basic-RE-list> | <lambda>
<basic-RE>  ::= <star> | <plus> | <ng-star> | <ng-plus> | <elementary-RE>
<star>  ::= <elementary-RE> "*"
<plus>  ::= <elementary-RE> "+"
<ng-star>  ::= <elementary-RE> "*?"
<ng-plus>  ::= <elementary-RE> "+?"
<elementary-RE>     ::= <group> | <any> | <eos> | <char> | <set>
<group>     ::=     "(" <RE> ")"
<any>   ::=     "."
<eos>   ::=     "$"
<char>  ::=     any non metacharacter | "\" metacharacter
<set>   ::=     <positive-set> | <negative-set>
<positive-set>  ::=     "[" <set-items> "]"
<negative-set>  ::=     "[^" <set-items> "]"
<set-items>     ::=     <set-item> | <set-item> <set-items>
<set-item>      ::=     <range> | <char>
<range>     ::=     <char> "-" <char>

Special Chars: | * + *? +? ( ) . $ \ [ [^ ] -

]]

function parser.parse(tokenList)
  local RE, unionList, simpleRE, basicRE, basicREList, elementaryRE, group, set, setItems, setItem

  local parseTable = {
    unionList = {["union"] = 1, default = 2},
    basicREList = {["union"] = 2, ["r-paren"] = 2, ["eof"] = 2, default = 1},
    elementaryRE = {["l-paren"] = 1, ["any"] = 2, ["char"] = 3, ["open-set"] = 4, ["open-negset"] = 4},
    setItems = {["close-set"] = 1, default = 2}
  }

  local function eat()
    return table.remove(tokenList, 1)
  end

  local function uneat(token)
    table.insert(tokenList, 1, token)
  end

  local function getMyType(name, index)
    local parseFn = parseTable[name][tokenList[index or 1].type] or parseTable[name].default

    if not parseFn then
      error("Unexpected token '" .. tokenList[index or 1].type .. "' at position " .. tokenList[index or 1].position, 0)
    end

    return parseFn
  end

  local function unrollLoop(container)
    local list, i = {}, 1

    while container do
      list[i], i = container[1], i + 1
      container = container[2]
    end

    return unpack(list)
  end

  -- <RE> ::= <simple-RE> <union-list>
  function RE()
    return {type = "RE", simpleRE(), unrollLoop(unionList())}
  end

  -- <union-list> ::= "|" <simple-RE> <union-list> | <lambda>
  function unionList()
    local parseFn = getMyType("unionList")

    if parseFn == 1 then
      eat()
      return {type = "unionList", simpleRE(), unionList()}
    else
      return
    end
  end

  -- <simple-RE> ::= <basic-RE> <basic-RE-list>
  function simpleRE()
    return {type = "simpleRE", basicRE(), unrollLoop(basicREList())}
  end

  -- <basic-RE> ::= <star> | <plus> | <ng-star> | <ng-plus> | <elementary-RE>
  function basicRE()
    local atom = elementaryRE()

    local token = eat()
    local type = token.type
    if type == "star" then
      return {type = "star", atom}
    elseif type == "plus" then
      return {type = "plus", atom}
    elseif type == "ng-star" then
      return {type = "ng-star", atom}
    elseif type == "ng-plus" then
      return {type = "ng-plus", atom}
    else
      uneat(token)
      return {type = "atom", atom}
    end
  end

  -- <basic-RE-list> ::= <basic-RE> <basic-RE-list> | <lambda>
  function basicREList()
    local parseFn = getMyType("basicREList")

    if parseFn == 1 then
      return {type = "basicREList", basicRE(), basicREList()}
    else
      return
    end
  end

  -- <elementary-RE> ::= <group> | <any> | <char> | <set>
  function elementaryRE()
    local parseFn = getMyType("elementaryRE")

    if parseFn == 1 then
      return group()
    elseif parseFn == 2 then
      eat()
      return {type = "any"}
    elseif parseFn == 3 then
      local token = eat()
      return {type = "char", value = token.source}
    elseif parseFn == 4 then
      return set()
    end
  end

  -- <group> ::= "(" <RE> ")"
  function group()
    eat()
    local rexp = RE()
    eat()

    return {type = "group", rexp}
  end

  --<set>   ::=     <positive-set> | <negative-set>
  function set()
    local openToken = eat()

    local ret
    if openToken.type == "open-set" then
      ret = {type = "set", unrollLoop(setItems())}
    else -- open-negset
      ret = {type = "negset", unrollLoop(setItems())}
    end

    eat()

    return ret
  end

  -- <set-items> ::= <set-item> | <set-item> <set-items>
  function setItems()
    local firstItem = setItem()
    local parseFn = getMyType("setItems")

    if parseFn == 1 then
      return {type = "setItems", firstItem}
    else
      return {type = "setItems", firstItem, setItems()}
    end
  end

  -- <set-item> ::= <range> | <char>
  function setItem()
    if tokenList[2].type == "range" then
      return {type = "range", start = eat().source, finish = (eat() and eat()).source}
    else
      return {type = "char", value = eat().source}
    end
  end

  local props = {
    clampStart = false,
    clampEnd = false
  }

  if tokenList[1].type == "start" then
    props.clampStart = true
    table.remove(tokenList, 1)
  end

  if tokenList[#tokenList - 1].type == "eos" then
    props.clampEnd = true
    table.remove(tokenList, #tokenList - 1)
  end

  local ret = RE()
  ret.properties = props
  return ret
end

return parser
