-- Regex Parser
-- Parses to an internal IL representation used for the construction of an NFA

local parser = {}

function parser.lexRegex(regexStr)
  local termEaten
  local function peek()
    return regexStr:sub(1, 1)
  end

  local function eatc()
    local c = peek()
    termEaten = termEaten .. c
    regexStr = regexStr:sub(2)
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
    ["$"] = "eos",
    ["\\"] = function()
      local metas = {d = "[0-9]", w = "[a-zA-Z]"}

      local c = eatc()
      if metas[c] then

        regexStr = metas[c] .. regexStr

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
        source = termEaten
      }
    end
  end

  return tokens
end

--[[

Grammar:

<RE>    ::=     <union> | <simple-RE>
<union>     ::= <RE> "|" <simple-RE>
<simple-RE>     ::=     <concatenation> | <basic-RE>
<concatenation>     ::= <simple-RE> <basic-RE>
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
  local RE, union, simpleRE, concatenation, basicRE, star, plus, ngStar, ngPlus, elementaryRE
  local group, any, eos, char, set, positiveSet, negativeSet, setItems, setItem, range

  local function lookFor(tokenType, reverseDirection)
    if reverseDirection then
      for i = #tokenList, 1, -1 do
        if tokenList[i].type == tokenType then
          return i
        end
      end
    else
      for i = 1, #tokenList do
        if tokenList[i].type == tokenType then
          return i
        end
      end
    end

    return false
  end

  local function subset(ts, start, endi)
    endi = endi or #ts

    local t = {}
    local j = 0
    for i = start, endi do
      j = j + 1
      t[j] = ts[i]
    end

    return t
  end

  -- <RE> ::= <union> | <simple-RE>
  function RE(ts)
    -- TODO: Parse simple-re's until there are no tokens left

    local ui = lookFor("union", true)
    if ui then
      return {type = "RE", union(ts, ui)}
    end

    return {type = "RE", simpleRE(ts)}
  end

  -- <union> ::= <RE> "|" <simple-RE>
  function union(ts, index)
    return {type = "union", RE(subset(ts, 1, index - 1)), simpleRE(subset(ts, index + 1))}
  end

  function simpleRE(ts)

  end
end

return parser
