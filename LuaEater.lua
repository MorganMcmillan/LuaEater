local char, sub, match = string.char, string.sub, string.match

local LuaEater = {}

local input_mt = {}

function input_mt:consume(n)
    return LuaEater.input(self.string, self.position + n), sub(self.string, self.position, self.position + n - 1)
end

function input_mt:get_char(i)
    i = self.position + i - 1
    return sub(self.string, i, i)
end

--- Returns how many characters are left to be consumed.
function input_mt:left()
    return #self.string - self.position
end

--- Wraps a string as input. All parser functions take in this input type for efficiency
function LuaEater.input(input, position)
    return setmetatable({
        string = input,
        position = position or 1
    }, input_mt)
end

function LuaEater.tag(tag)
    return function(input)
        local unconsumed, expected_tag = input:consume(#tag)
        if expected_tag ~= tag then
            return false, "Tag"
        end
        return unconsumed, expected_tag
    end
end

--- Succeeds if the input is empty
function LuaEater.eof()
    return function(input)
        if input:left() ~= 0 then
            return false, "Eof"
        end
        return input
    end
end

--- Ensures that a parser consumes all its input.
function LuaEater.all_consuming(parser)
    return function(input)
        local input, output = parser(input)
        if not input then return false, output end
        if input:left() ~= 0 then return false, "All Consuming" end
        return input, output
    end
end

--- Conditionally calls a parser
function LuaEater.cond(cond, parser)
    if cond then
        return parser
    else
        return function(input)
            return input
        end
    end
end

--- Takes n characters from string
function LuaEater.take(n)
    return function(input)
        if n < input:left() then
            return false, "Take"
        end
        return input:consume(n)
    end
end

-- Takes characters while a pattern matches or a predicate returns true
function LuaEater.take_while(cond)
    -- Regex pattern
    if type(cond) == "string" then
        return function(input)
            local length = 1
            while match(input:get_char(length), cond) do
                length = length + 1
            end
            return input:consume(length - 1)
        end
    -- Predicate function
    elseif type(cond) == "function" then
        return function(input)
            local length = 1
            while cond(input:get_char(length)) do
                length = length + 1
            end
            return input:consume(length - 1)
        end
    -- Character set
    elseif type(cond) == "table" then
        return function(input)
            local length = 1
            while cond[input:get_char(length)] do
                length = length + 1
            end
            return input:consume(length - 1)
        end
    end
end

-- Takes characters while not a pattern doesn't match or a predicate returns false
function LuaEater.take_until(cond)
    -- Regex pattern
    if type(cond) == "string" then
        return function(input)
            local length = 1
            while not match(input:get_char(length), cond) do
                length = length + 1
            end
            return input:consume(length - 1)
        end
    -- Predicate function
    elseif type(cond) == "function" then
        return function(input)
            local length = 1
            while not cond(input:get_char(length)) do
                length = length + 1
            end
            return input:consume(length - 1)
        end
    -- Character set
    elseif type(cond) == "table" then
        return function(input)
            local length = 1
            while not cond[input:get_char(length)] do
                length = length + 1
            end
            return input:consume(length - 1)
        end
    end
end

--- Thin wrapper around `string.match`. Prepends "^" to ensure matching at the start of the string.
function LuaEater.match(pattern)
    return function(input)
        local start, finish = string.find(input.string, pattern, input.position)
        if not start then return false, "Match" end
        return input:consume(finish - start + 1)
    end
end

--- Applies every parser in sequence, collecting their results.
function LuaEater.all(parsers)
    return function(input)
        local results = {}
        for i = 1, #parsers do
            local ok, result = parsers[i](input)
            if not ok then
                return false, result
            end
            input, results[#results+1] = ok, result
        end
        return input, results
    end
end

--- Returns the first okay result of the parsers.
function LuaEater.any(parsers)
    return function(input)
        for i = 1, #parsers do
            local ok, result = parsers[i](input)
            if ok then
                return ok, result
            end
        end
        return false, "Any"
    end
end

function LuaEater.peek(parser)
    return function(input)
        local ok, output = parser(input)
        if not ok then return false, output end
        -- Don't consume the input
        return input, output
    end
end

--- Optionally applies a parser. This function never errors.
function LuaEater.opt(parser)
    return function(input)
        local ok, output = parser(input)
        -- Instead of erroring, do nothing
        if not ok then return input end
        return ok, output
    end
end

--- Returns ok when the parser errors
function LuaEater.invert(parser)
    return function(input)
        if parser(input) then return false, "Invert" end
        return input
    end
end

--- Applies a function to the result of a parser
function LuaEater.map(parser, f)
    return function(input)
        local ok, output = parser(input)
        if not ok then return false, output end
        return ok, f(output)
    end
end

--- Applies a parser to the result of another parser
function LuaEater.map_parser(outer, inner)
    return function(input)
        local ok, output = outer(input)
        if not ok then return false, output end
        ok, output = inner(LuaEater.input(output))
        if not ok then return false, output end
        return ok, output
    end
end

--- Applies two parsers after each other
function LuaEater.pair(first, second)
    return function(input)
        local ok, first_output = first(input)
        if not ok then return false, first_output end
        local ok, second_output = second(ok)
        if not ok then return false, second_output end
        return ok, { first_output, second_output }
    end
end

--- Applies two parsers separated by another parser
function LuaEater.separated_pair(first, sep, second)
    return function(input)
        local ok, first_output = first(input)
        if not ok then return false, first_output end
        local ok, sep_result = sep(ok)
        if not ok then return false, sep_result end
        local ok, second_output = second(ok)
        if not ok then return false, second_output end
        return ok, { first_output, second_output }
    end
end

--- Applies `parser` many times, separated by `sep`. Stops when `sep` fails. Includes the last element.
function LuaEater.separated_list(parser, sep)
    return function(input)
        local outputs, output = {}
        while true do
            input, output = parser(input)
            if not input then return false, output end
            outputs[#outputs+1] = output
            local sep_input = sep(input)
            if not sep_input then break end
            input = sep_input
        end
        return input, outputs
    end
end

--- Returns only the result of parser, if it is preceded by the other parser. Opposite of `terminated`.
function LuaEater.preceded(precedent, parser)
    return function(input)
        local input, preceded = precedent(input)
        if not input then return false, preceded end
        return parser(input)
    end
end

--- Returns only the result of parser, if it is followed by the terminator. Opposite of `preceded`.
function LuaEater.terminated(parser, terminator)
    return function(input)
        local input, result = parser(input)
        if not input then return false, result end
        local ok, terminated = terminator(input)
        if not ok then return false, terminated end
        return input, result
    end
end

--- Applies each parser and only returns the output of the second. Useful for pairs of tags such as parenthesis. Can be thought of as a combination of `preceded` and `terminated`.
function LuaEater.delimited(first, second, third)
    return function(input)
        input, first = first(input)
        if not input then return false, first end
        input, second = second(input)
        if not input then return false, second end
        input, third = third(input)
        if not input then return false, third end
        return input, second
    end
end

--- Always fails
function LuaEater.fail(message)
    return function()
        return false, message
    end
end

--- Always succeeds
function LuaEater.success()
    return function(input)
        return input
    end
end

--- Repeats a parser 0 or more times
function LuaEater.many0(parser)
    return function(input)
        local outputs, output = {}
        repeat
            input, output = parser(input)
            if input then
                outputs[#outputs+1] = output
            end
        until not input
        return input, outputs
    end
end

--- Repeats a parser 1 or more times
function LuaEater.many1(parser)
    return function(input)
        local outputs, output = {}
        repeat
            input, output = parser(input)
            if input then
                outputs[#outputs+1] = output
            end
        until not input
        if #outputs == 0 then return false, "Many1" end
        return input, outputs
    end
end

function LuaEater.many_m_n(parser, min, max)
    return function(input)
        local outputs, output = {}
        repeat
            input, output = parser(input)
            if input then
                outputs[#outputs+1] = output
            end
            if #outputs > max then return false, "ManyMN" end
        until not input
        if #outputs < min then return false, "ManyMN" end
        return input, outputs
    end
end

--- Applies `parser` several times until `till` produces a result. Errors if `parser` errors.
function LuaEater.many_till(parser, till)
    return function(input)
        local outputs, output = {}
        while not till(input) do
            input, output = parser(input)
            if not input then return false, output end
            outputs[#outputs+1] = output
        end
        return input, outputs
    end
end

---
-- Character Type Parsers
---

local digit_char = {}
local hex_char = {}
local lower_char = {}
local upper_char = {}
local alpha_char = {}
local alphanumeric_char = { _ = true }
local punctuation_char = {}
local space_char = {
    [" "] = true,
    ["\t"] = true,
    ["\v"] = true
}
local multispace_char = {
    [" "] = true,
    ["\t"] = true,
    ["\v"] = true,
    ["\r"] = true,
    ["\n"] = true
}

-- Fill character type sets

-- Digits
for i = 48, 57 do
    local c = char(i)
    digit_char[c] = true
    hex_char[c] = true
    alphanumeric_char[c] = true
end

-- Hex digits (lower)
for i = 97, 102 do
    hex_char[char(i)] = true
end

-- Hex digits (upper)
for i = 65, 70 do
    hex_char[char(i)] = true
end

-- Lowercase
for i = 97, 122 do
    local c = char(i)
    lower_char[c] = true
    alpha_char[c] = true
    alphanumeric_char[c] = true
end

-- Uppercase
for i = 65, 90 do
    local c = char(i)
    upper_char[c] = true
    alpha_char[c] = true
    alphanumeric_char[c] = true
end

-- Punctuation
local punctuation = "`~,<.>/?!@#$%^&*()-+=[{]}\\|;:'\""
for i = 1, #punctuation do
    punctuation_char[sub(punctuation, i, i)] = true
end

function LuaEater.alpha0()
    return LuaEater.take_while(alpha_char)
end

function LuaEater.alpha1()
    return function(input)
        local input, output = LuaEater.alpha0()(input)
        if #output == 0 then return false, "Alpha1" end
        return input, output
    end
end

function LuaEater.alphanumeric0()
    return LuaEater.take_while(alphanumeric_char)
end

function LuaEater.alphanumeric1()
    return function(input)
        local input, output = LuaEater.alphanumeric0()(input)
        if #output == 0 then return false, "Alphanumeric1" end
        return input, output
    end
end
function LuaEater.digit0()
    return LuaEater.take_while(digit_char)
end

function LuaEater.digit1()
    return function(input)
        local input, output = LuaEater.digit0()(input)
        if #output == 0 then return false, "Digit1" end
        return input, output
    end
end

function bin_digit0()
    return LuaEater.take_while{ ["0"] = true, ["1"] = true }
end

function LuaEater.bin_digit1()
    return function(input)
        local input, output = LuaEater.bin_digit0()(input)
        if #output == 0 then return false, "BinDigit1" end
        return input, output
    end
end

function LuaEater.hex_digit0()
    return LuaEater.take_until(hex_char)
end

function LuaEater.hex_digit1()
    return function(input)
        local input, output = LuaEater.hex_digit0()(input)
        if #output == 0 then return false, "HexDigit1" end
        return input, output
    end
end

function LuaEater.space0()
    return LuaEater.take_while(space_char)
end

function LuaEater.space1()
    return function(input)
        local input, output = LuaEater.space0()(input)
        if #output == 0 then return false, "Space1" end
        return input, output
    end
end

function LuaEater.multispace0()
    return LuaEater.take_while(multispace_char)
end

function LuaEater.multispace1()
    return function(input)
        local input, output = LuaEater.multispace0()(input)
        if #output == 0 then return false, "MultiSpace1" end
        return input, output
    end
end

function LuaEater.crlf()
    return LuaEater.tag"\r\n"
end

function LuaEater.newline()
    return LuaEater.tag"\n"
end

function LuaEater.tab()
    return LuaEater.tag"\t"
end


function LuaEater.one_of(characters)
    if type(characters) ~= "table" then
        local charset = {}
        for i = 1, #characters do
            charset[sub(characters, i, i)] = true
        end
        characters = charset
    end
    return function(input)
        local ok, char = input:consume(1)
        if not characters[char] then return false, "OneOf" end
        return ok, char
    end
end

function LuaEater.none_of(characters)
    if type(characters) ~= "table" then
        local charset = {}
        for i = 1, #characters do
            charset[sub(characters, i, i)] = true
        end
        characters = charset
    end
    return function(input)
        local ok, char = input:consume(1)
        if characters[char] then return false, "NoneOf" end
        return ok, char
    end
end

---
-- Character Tables
---

local CharTable = {}
CharTable.__index = CharTable
LuaEater.CharTable = CharTable

function CharTable:new(t)
    return setmetatable(t or {}, self)
end

function CharTable:__call(input)
    local parser = self[sub(input.string, input.position, input.position)]
    if not parser then return false, "CharTable" end
    return parser(input)
end

--- Assigns parser to alphabetic (a-zA-Z) ASCII characters
function CharTable:alphabetic(parser)
    return self:lower(parser):upper(parser)
end

--- Assigns parser to alphanumeric (a-zA-Z0-9_) ASCII characters
function CharTable:alphanumeric(parser)
    self["_"] = parser
    return self:alphabetic(parser):numeric(parser)
end

--- Assigns parser to numeric (0-9) ASCII characters
function CharTable:numeric(parser)
    parser = parser or LuaEater.digit1()
    for i = 48, 57 do
        self[char(i)] = parser
    end
    return self
end

--- Assigns parser to lowercase (a-z) ASCII characters
function CharTable:lower(parser)
    for i = 97, 122 do
        self[char(i)] = parser
    end
    return self
end

--- Assigns parser to uppercase (A-Z) ASCII characters
function CharTable:upper(parser)
    for i = 65, 90 do
        self[char(i)] = parser
    end
    return self
end

--- Assigns parser to whitespace (\f\n\r\t\v) ASCII characters
function CharTable:whitespace(parser)
    self["\r"] = parser
    self["\n"] = parser
    self["\t"] = parser
    self["\v"] = parser
    self[" "] = parser
    return self
end

--- Assigns parser to punctuation ASCII characters
function CharTable:punctuation(parser)
    return self:set("`~,<.>/?!@#$%^&*()-+=[{]}\\|;:'\"", parser)
end

--- Assigns parser to quotation ASCII characters
function CharTable:quotation(parser)
    self["'"] = parser
    self['"'] = parser
    self["`"] = parser
    return self
end

--- Assigns parser to the null character
function CharTable:null(parser)
    self["\0"] = parser
    return self
end

--- Assigns parser to the given characters
function CharTable:set(characters, parser)
    for i = 1, #characters do
        self[sub(characters, i, i)] = parser
    end
    return self
end