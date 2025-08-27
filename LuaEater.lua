local char, sub, match = string.char, string.sub, string.match

local LuaEater = {}

local function consume(input, n)
    return sub(input, n + 1), sub(input, 1, n)
end

--- @alias Parser<T> fun(string): string | false, T | string

--- Recognizes a specific series of characters.
---@param tag string
---@return Parser
function LuaEater.tag(tag)
    return function(input)
        local unconsumed, expected_tag = consume(input, #tag)
        if expected_tag ~= tag then
            return false, "Tag"
        end
        return unconsumed, expected_tag
    end
end

--- Case-insensitive version of `tag`.
---@param tag string
---@return Parser
function LuaEater.tag_case_insensitive(tag)
    return function(input)
        local unconsumed, expected_tag = consume(input, #tag)
        if expected_tag:lower() ~= tag:lower() then
            return false, "tagCaseInsensitive"
        end
        return unconsumed, expected_tag
    end
end

--- Succeeds if the input is empty
--- @type Parser
function LuaEater.eof(input)
    if #input ~= 0 then
        return false, "Eof"
    end
    return input
end

--- Ensures that a parser consumes all its input.
---@param parser Parser
---@return Parser
function LuaEater.all_consuming(parser)
    return function(input)
        local input, output = parser(input)
        if not input then return false, output end
        if #input ~= 0 then return false, "AllConsuming" end
        return input, output
    end
end

--- Conditionally calls a parser
---@param cond boolean
---@param parser Parser
---@return Parser
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
---@param n integer
---@return Parser
function LuaEater.take(n)
    return function(input)
        if n > #input then
            return false, "Take"
        end
        return consume(input, n)
    end
end

--- Wraps a table as a function.
local function wrap_table(table)
    return function(index)
        return table[index]
    end
end

--- Takes characters while a pattern matches or a predicate returns true
---@param cond string | table<string, true> | fun(string): boolean
---@return Parser
function LuaEater.take_while(cond)
    local predicate
    -- Regex pattern
    if type(cond) == "string" then
        predicate = function(char) return match(char, cond) end
    -- Character set
    elseif type(cond) == "table" then
        predicate = wrap_table(cond)
    -- Predicate function
    else
        predicate = cond
    end

    return function(input)
        local length = 1
        while predicate(sub(input, length, length)) do
            length = length + 1
        end
        return consume(input, length - 1)
    end
end

--- Takes characters while a pattern matches or a predicate returns true
---@param cond string | table<string, true> | fun(string): boolean
---@return Parser
function LuaEater.take_while_m_n(min, max, cond)
    local predicate
    -- Regex pattern
    if type(cond) == "string" then
        predicate = function(char) return match(char, cond) end
    -- Character set
    elseif type(cond) == "table" then
        predicate = wrap_table(cond)
    -- Predicate function
    else
        predicate = cond
    end

    return function(input)
        local length = 1
        for i = 1, max do
            if not predicate(sub(input, length, length)) then break end
            length = length + 1
        end
        if length - 1 < min then return false, "TakeWhileMN" end
        return consume(input, length - 1)
    end
end

--- Takes characters until a predicate stops matching
---@param cond string | table<string, true> | fun(string): boolean
---@return Parser
function LuaEater.take_until(cond)
    local predicate
    -- Regex pattern
    if type(cond) == "string" then
        predicate = function(char) return match(char, cond) end
    -- Character set
    elseif type(cond) == "table" then
        predicate = wrap_table(cond)
    -- Predicate function
    else
        predicate = cond
    end

    return function(input)
        local length = 1
        while not predicate(sub(input, length, length)) do
            length = length + 1
        end
        return consume(input, length - 1)
    end
end

--- Thin wrapper around `string.match`. Prepends "^" to ensure matching at the start of the string.
---@param pattern string
---@return Parser
function LuaEater.match(pattern)
    return function(input)
        local start, finish = string.find(input.string, pattern, input.position)
        if not start then return false, "Match" end
        return consume(input, finish - start + 1)
    end
end

--- Applies every parser in sequence, collecting their results.
---@param parsers Parser[]
---@return Parser<string[]>
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
---@param parsers Parser[]
---@return Parser
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

--- Returns the result of a parser without consuming any input.
---@param parser Parser
---@return Parser
function LuaEater.peek(parser)
    return function(input)
        local ok, output = parser(input)
        if not ok then return false, output end
        -- Don't consume the input
        return input, output
    end
end

--- Optionally applies a parser. This function never errors.
---@param parser Parser
---@return Parser<any | nil>
function LuaEater.maybe(parser)
    return function(input)
        local ok, output = parser(input)
        -- Instead of erroring, do nothing
        if not ok then return input end
        return ok, output
    end
end

--- Returns ok when the parser errors
---@param parser Parser
---@return Parser
function LuaEater.invert(parser)
    return function(input)
        if parser(input) then return false, "Invert" end
        return input
    end
end

--- Verifies that a parser matches a predicate.
---@param parser Parser
---@param predicate fun(string): boolean
---@return Parser
function LuaEater.verify(parser, predicate)
    return function(input)
        local ok, output = parser(input)
        if not ok then return false, output end
        if not predicate(output) then return false, "Verify" end
        return ok, output
    end
end

--- Verifies that a parser matches a predicate, and returns the result of that predicate.
---@generic T
---@param parser Parser
---@param predicate fun(string): T|nil
---@return Parser<T>
function LuaEater.verify_map(parser, predicate)
    return function(input)
        local ok, output = parser(input)
        if not ok then return false, output end
        output = predicate(output)
        if not output then return false, "Verify" end
        return ok, output
    end
end

--- Applies a parser and returns the consumed input instead of the parser's output.
---@param parser Parser
---@return Parser
function LuaEater.recognize(parser)
    return function(input)
        local left = #input
        local ok, output = parser(input)
        if not ok then return false, output end
        local input, consumed = consume(input, left - #ok)
        return input, consumed, output
    end
end

--- Applies a function to the result of a parser
---@generic T
---@param parser Parser
---@param f table | fun(string): T
---@return Parser<T>
function LuaEater.map(parser, f)
    if type(f) == "table" then
        return function(input)
            local ok, output = parser(input)
            if not ok then return false, output end
            return ok, f[output]
        end
    else
        return function(input)
            local ok, output = parser(input)
            if not ok then return false, output end
            return ok, f(output)
        end
    end
end

--- Applies a parser to the result of another parser
---@generic T
---@param outer Parser
---@param inner Parser<T>
---@return Parser<T>
function LuaEater.map_parser(outer, inner)
    return function(input)
        local ok, output = outer(input)
        if not ok then return false, output end
        return inner(output)
    end
end

--- Maps the ok output of a parser to a specific value.
---@generic T
---@param parser Parser
---@param value T
---@return Parser<T>
function LuaEater.value(parser, value)
    return function(input)
        local ok, output = parser(input)
        if not ok then return false, output end
        return ok, value
    end
end

--- Maps the output of a parser to either an okay value or an error value, based on whether the parser was successful.
--- @generic T
--- @generic E
--- @param parser Parser
--- @param ok T
--- @param err E
--- @return Parser<T|E>
function LuaEater.either(parser, ok, err)
    return function(input)
        local next_input = parser(input)
        if next_input then
            return next_input, ok
        else
            return input, err
        end
    end
end

--- Applies two parsers after each other
---@param first Parser
---@param second Parser
---@return Parser<any[]>
function LuaEater.pair(first, second)
    return function(input)
        local ok, first_output = first(input)
        if not ok then return false, first_output end
        local ok, second_output = second(ok)
        if not ok then return false, second_output end
        return ok, { first_output, second_output }
    end
end

---@param first Parser
---@param sep Parser
---@param second Parser
---@return Parser<any[]>
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

--- Applies `parser` many times, separated by `sep`.
---@param parser Parser
---@param sep Parser
---@return Parser<string[]>
function LuaEater.separated_list(parser, sep)
    return function(input)
        local outputs = {}
        while true do
            local ok, output = parser(input)
            if not ok then break end
            outputs[#outputs+1] = output
            input = ok
            local sep_input = sep(input)
            if not sep_input then break end
            input = sep_input
        end
        return input, outputs
    end
end

--- Returns only the result of parser, if it is preceded by the other parser. Opposite of `terminated`.
---@param precedent Parser
---@param parser Parser
---@return Parser
function LuaEater.preceded(precedent, parser)
    return function(input)
        local input, preceded = precedent(input)
        if not input then return false, preceded end
        return parser(input)
    end
end

--- Returns only the result of parser, if it is followed by the terminator. Opposite of `preceded`.
---@param parser Parser
---@param terminator Parser
---@return Parser
function LuaEater.terminated(parser, terminator)
    return function(input)
        local input, result = parser(input)
        if not input then return false, result end
        local input, terminated = terminator(input)
        if not input then return false, terminated end
        return input, result
    end
end

--- Applies each parser and only returns the output of the second. Useful for pairs of tags such as parenthesis. Can be thought of as a combination of `preceded` and `terminated`.
---@param first Parser
---@param second Parser
---@param third Parser
---@return Parser
function LuaEater.delimited(first, second, third)
    return function(input)
        local input, first_output = first(input)
        if not input then return false, first_output end
        local input, second_output = second(input)
        if not input then return false, second_output end
        local input, third_output = third(input)
        if not input then return false, third_output end
        return input, second_output
    end
end

--- Parses a sequence containing escaped characters as a list.
--- Every first element is the unescaped sequence of characters,
--- every second element is the escape characters,
--- and every third element is the escaped sequence.
--- @param normal Parser the normal, unescaped character parser. It must not accept the escape sequence.
--- @param control Parser the parser for the escape sequence. If this fails then the parser finishes.
--- @param escapable Parser the parser for the valid escape characters. If this parser fails then `escaped_list` fails.
--- @return Parser<string[]>
function LuaEater.escaped_list(normal, control, escapable)
    return function(input)
        local outputs = {}
        while true do
            local ok, normal_output = normal(input)
            outputs[#outputs+1] = ok and normal_output or ""
            input = ok or input
            local ok, control_output = control(input)
            if not ok then return input, outputs end
            outputs[#outputs+1] = control_output
            local ok, escaped_output = escapable(ok)
            if not ok then return false, escaped_output end
            outputs[#outputs+1] = escaped_output
            input = ok
        end
    end
end

--- Parses a sequence containing escaped characters as a string.
--- @param normal Parser the normal, unescaped character parser. It must not accept the escape sequence.
--- @param control Parser the parser for the escape sequence. If this fails then the parser finishes.
--- @param escapable Parser the parser for the valid escape characters. If this parser fails then `escaped` fails.
--- @return Parser
function LuaEater.escaped(normal, control, escapable)
    return LuaEater.map(LuaEater.escaped_list(normal, control, escapable), table.concat)
end

--- Parses a sequence containing escaped characters as a list, transforming each escape sequence into the result of `escapable`.
--- Every odd element is the unescaped sequence of characters,
--- and every even element is the escaped sequence mapped to the parser.
--- @param normal Parser the normal, unescaped character parser. It must not accept the escape sequence.
--- @param control Parser the parser for the escape sequence. If this fails then the parser finishes.
--- @param escapable Parser the parser for the valid escape characters. If this parser fails then `escaped` fails.
--- @return Parser
function LuaEater.escaped_transform_list(normal, control, escapable)
    return function(input)
        local outputs = {}
        while true do
            local ok, normal_output = normal(input)
            outputs[#outputs+1] = ok and normal_output or ""
            input = ok or input
            ok = control(input)
            if not ok then return input, outputs end
            local ok, escaped_output = escapable(ok)
            if not ok then return false, escaped_output end
            outputs[#outputs+1] = escaped_output
            input = ok
        end
    end
end

--- Parses a sequence containing escaped characters as a string, transforming each escape sequence into the result of `escapable`.
--- @param normal Parser the normal, unescaped character parser. It must not accept the escape sequence.
--- @param control Parser the parser for the escape sequence. If this fails then the parser finishes.
--- @param escapable Parser the parser for the valid escape characters. If this parser fails then `escaped` fails.
--- @return Parser
function LuaEater.escaped_transform(normal, control, escapable)
    return LuaEater.map(LuaEater.escaped_transform_list(normal, control, escapable), table.concat)
end

--- Always fails
---@param message string
---@return Parser<false>
function LuaEater.fail(message)
    return function()
        return false, message
    end
end

--- Always succeeds
--- @type Parser
function LuaEater.success(input)
    return input
end

--- Converts any parsing error to the specified error.
--- @param parser Parser
--- @param error string
--- @return Parser
function LuaEater.context(parser, error)
    return function(input)
        local ok, output = parser(input)
        if not ok then return false, error end
        return ok, output
    end
end


--- Repeats a parser 0 or more times.
---@param parser Parser
---@return Parser<string[]>
function LuaEater.many0(parser)
    return function(input)
        local outputs = {}
        while true do
            local ok, output = parser(input)
            if not ok then break end
            outputs[#outputs+1] = output
            input = ok
        end
        return input, outputs
    end
end


--- Repeats a parser 1 or more times.
function LuaEater.many1(parser)
    return function(input)
        local outputs = {}
        while true do
            local ok, output = parser(input)
            if not ok then break end
            outputs[#outputs+1] = output
            input = ok
        end
        if #outputs == 0 then return false, "Many1" end
        return input, outputs
    end
end

--- Repeats a parser between `min` and `max` times
function LuaEater.many_m_n(min, max, parser)
    return function(input)
        local outputs = {}
        for i = 1, max do
            local ok, output = parser(input)
            if not ok then break end
            outputs[#outputs+1] = output
            input = ok
        end
        if #outputs < min then return false, "ManyMN" end
        return input, outputs
    end
end

--- Applies `parser` several times until `till` produces a result. Errors if `parser` errors.
---@param parser Parser
---@param till Parser
---@return Parser
function LuaEater.many_till(parser, till)
    return function(input)
        local outputs, output = {}, nil
        while not till(input) do
            input, output = parser(input)
            if not input then return false, output end
            outputs[#outputs+1] = output
        end
        return input, outputs
    end
end

--- Parses a length and then applies the parser that many times.
---@param count Parser<integer>
---@param parser Parser
---@return Parser<any[]>
function LuaEater.length_value(count, parser)
    return function(input)
        local input, length = count(input)
        if not input then return false, length end
        local outputs, output = {}, nil
        for i = 1, length do
            input, output = parser(input)
            if not input then return false, output end
            outputs[i] = output
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

--- Takes in a parser consuming 0 or more characters and wraps it in a function consuming 1 or more characters.
local function make1(parser, err_name)
    return function(input)
        local input, output = parser(input)
        if not input then return false, output end
        if #output == 0 then return false, err_name end
        return input, output
    end
end

LuaEater.alpha0 = LuaEater.take_while(alpha_char)
LuaEater.alpha1 = make1(LuaEater.alpha0, "Alpha1")

LuaEater.alphanumeric0 = LuaEater.take_while(alphanumeric_char)
LuaEater.alphanumeric1 = make1(LuaEater.alphanumeric0, "Alphanumeric1")

LuaEater.digit0 = LuaEater.take_while(digit_char)
LuaEater.digit1 = make1(LuaEater.digit0, "Digit1")

LuaEater.bin_digit0 = LuaEater.take_while{ ["0"] = true, ["1"] = true }
LuaEater.bin_digit1 = make1(LuaEater.bin_digit0, "BinDigit1")

LuaEater.oct_digit0 = LuaEater.take_while{
    ["0"] = true,
    ["1"] = true,
    ["2"] = true,
    ["3"] = true,
    ["4"] = true,
    ["5"] = true,
    ["6"] = true,
    ["7"] = true,
}
LuaEater.oct_digit1 = make1(LuaEater.oct_digit0, "OctDigit1")

LuaEater.hex_digit0 = LuaEater.take_until(hex_char)
LuaEater.hex_digit1 = make1(LuaEater.hex_digit0, "HexDigit1")

LuaEater.space0 = LuaEater.take_while(space_char)
LuaEater.space1 = make1(LuaEater.space0, "Space1")

LuaEater.multispace0 = LuaEater.take_while(multispace_char)
LuaEater.multispace1 = make1(LuaEater.multispace0, "Multispace1")

LuaEater.crlf = LuaEater.tag"\r\n"
LuaEater.newline = LuaEater.tag"\n"
LuaEater.tab = LuaEater.tag"\t"

--- Consumes a single character and checks that it's equal.
---@param character string
---@return Parser
function LuaEater.char(character)
    return function(input)
        local input, c = consume(input, 1)
        if character ~= c then return false, "Char" end
        return input, c
    end
end

--- Matches a single character against a set or string of characters.
--- @param characters string | {string: true}
--- @return Parser
function LuaEater.one_of(characters)
    if type(characters) ~= "table" then
        local charset = {}
        for i = 1, #characters do
            charset[sub(characters, i, i)] = true
        end
        characters = charset
    end
    return function(input)
        local input, c = consume(input, 1)
        if not characters[c] then return false, "OneOf" end
        return input, c
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
        local input, c = consume(input, 1)
        if characters[c] then return false, "NoneOf" end
        return input, c
    end
end

--- Recognizes one character that satisfies a predicate
function LuaEater.satisfy(predicate)
    return function(input)
        local input, c = consume(input, 1)
        if not predicate(c) then return false, "Satisfy" end
        return input, c
    end
end

--- Returns the remaining input
function LuaEater.rest(input)
    return consume(input, #input)
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
    parser = parser or LuaEater.alpha0
    return self:lower(parser):upper(parser)
end

--- Assigns parser to alphanumeric (a-zA-Z0-9_) ASCII characters
function CharTable:alphanumeric(parser)
    parser = parser or LuaEater.alphanumeric0
    self["_"] = parser
    return self:alphabetic(parser):numeric(parser)
end

--- Assigns parser to numeric (0-9) ASCII characters
function CharTable:numeric(parser)
    parser = parser or LuaEater.digit0
    for i = 48, 57 do
        self[char(i)] = parser
    end
    return self
end

--- Assigns parser to lowercase (a-z) ASCII characters
function CharTable:lower(parser)
    parser = parser or LuaEater.alpha0
    for i = 97, 122 do
        self[char(i)] = parser
    end
    return self
end

--- Assigns parser to uppercase (A-Z) ASCII characters
function CharTable:upper(parser)
    parser = parser or LuaEater.alpha0
    for i = 65, 90 do
        self[char(i)] = parser
    end
    return self
end

--- Assigns parser to whitespace (\f\n\r\t\v) ASCII characters
function CharTable:whitespace(parser)
    parser = parser or LuaEater.multispace0
    self["\r"] = parser
    self["\n"] = parser
    self["\t"] = parser
    self["\v"] = parser
    self[" "] = parser
    return self
end

--- Assigns parser to punctuation ASCII characters
function CharTable:punctuation(parser)
    parser = parser or LuaEater.take_while(punctuation_char)
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

return LuaEater