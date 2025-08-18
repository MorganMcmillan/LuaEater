local sub, match = string.sub, string.match

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
        if expected_tag == tag then
            return unconsumed, expected_tag
        end
        return false, "Tag"
    end
end

--- Succeeds if the input is empty
function LuaEater.eof()
    return function(input)
        if input:left() == 0 then
            return input
        end
        return false, "Eof"
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
        if ok then
            -- Don't consume the input
            return input, output
        end
        return false, output
    end
end

--- Optionally applies a parser. This function never errors.
function LuaEater.opt(parser)
    return function(input)
        local ok, output = parser(input)
        if ok then
            return ok, output
        end
        -- Instead of erroring, do nothing
        return input
    end
end

--- Returns ok when the parser errors
function LuaEater.invert(parser)
    return function(input)
        if parser(input) then
            return false, "Invert"
        end
        return input
    end
end

--- Applies a function to the result of a parser
function LuaEater.map(parser, f)
    return function(input)
        local ok, output = parser(input)
        if ok then
            return ok, f(output)
        end
        return false, output
    end
end

--- Applies a parser to the result of another parser
function LuaEater.map_parser(outer, inner)
    return function(input)
        local ok, output = outer(input)
        if ok then
            local inner_ok, inner_output = inner(output)
            if inner_ok then
                return ok, inner_output
            end
            return false, inner_output
        end
        return false, output
    end
end

--- Applies two parsers after each other
function LuaEater.pair(first, second)
    return function(input)
        local ok, first_output = first(input)
        if ok then
            local ok, second_output = second(ok)
            if ok then
                return ok, { first_output, second_output }
            end
            return false, second_output
        end
        return false, first_output
    end
end

--- Returns only the result of parser, if it is preceded by the other parser. Opposite of `terminated`.
function LuaEater.preceded(precedent, parser)
    return function(input)
        local input, result = precedent(input)
        if input then
            return parser(input)
        end
        return false, result
    end
end

--- Returns only the result of parser, if it is followed by the terminator. Opposite of `preceded`.
function LuaEater.terminated(parser, terminator)
    return function(input)
        local input, result = parser(input)
        if input then
            local ok, terminated = terminator(input)
            if ok then
                return input, result
            end
            return false, terminated
        end
        return false, result
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

function LuaEater.fail(message)
    return function()
        return false, message
    end
end

function LuaEater.success()
    return function(input)
        return input
    end
end