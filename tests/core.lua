local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
    "Eof",
    function ()
        local i = LuaEater.input("abc123")
        local rest, output = assert(LuaEater.rest(i))
        assert(LuaEater.eof(rest))
        print(output, rest:left())
    end,
    "Left and Take",
    function ()
        local i = LuaEater.input("abc123")
        print(i:left())
        local rest, output = assert(LuaEater.take(6)(i))
        x.assertEq(rest:left(), 0)
    end,
    "Take errors when n is larger than input size",
    function ()
        local i = LuaEater.input("abc123")
        x.assertNot(LuaEater.take(7)(i))
    end,
    "Rest is all consuming",
    function ()
        local i = LuaEater.input("abc123")
        assert(LuaEater.all_consuming(LuaEater.rest)(i))
    end,
    "All consuming fails when there's input left",
    function ()
        local i = LuaEater.input("abc123")
        x.assertNot(LuaEater.all_consuming(LuaEater.success)(i))
    end,
    --- Section unnamed
    "All combinator",
    function ()
        local i = LuaEater.input("abc123")
        local _, output = assert(LuaEater.all{LuaEater.alpha1, LuaEater.digit1}(i))
        x.assertEq(output[1], "abc")
        x.assertEq(output[2], "123")
    end,
    "Any combinator",
    function ()
        local i = LuaEater.input("123")
        local _, output = assert(LuaEater.any{LuaEater.alpha1, LuaEater.digit1}(i))
        x.assertEq(output, "123")
    end,
    "Multiple space and lines",
    function ()
        for _, input in ipairs{"local x=123", "local x = 123", "local     \t x  =\n\n123"} do
            local i = LuaEater.input("local x=123")
            local _, output = assert(LuaEater.all{
                LuaEater.tag"local",
                LuaEater.preceded(LuaEater.multispace1, LuaEater.alphanumeric1),
                LuaEater.preceded(LuaEater.multispace0, LuaEater.tag"="),
                LuaEater.preceded(LuaEater.multispace0, LuaEater.digit1),
                LuaEater.eof
            }(i))

            x.assertEq(output[1], "local")
            x.assertEq(output[2], "x")
            x.assertEq(output[3], "=")
            x.assertEq(output[4], "123")
        end
    end,
    "One of",
    function ()
        local i = LuaEater.input("abcd")
        x.assert(LuaEater.all_consuming(LuaEater.many0(LuaEater.one_of("dcba")))(i))
    end,
    "Recursive expression parser",
    function ()
        local number = LuaEater.map(LuaEater.digit1, tonumber)
        local operator = LuaEater.one_of("+-*/")

        local function expression(input)
            return LuaEater.all{
                number,
                LuaEater.preceded(LuaEater.multispace0, operator),
                LuaEater.preceded(LuaEater.multispace0, LuaEater.maybe(LuaEater.any{expression, number}))
            }(input)
        end

        local input = "1 + 2 * 3 / 4 - 5"
        local i = LuaEater.input(input)
        local _, expr = x.assert(LuaEater.recognize(expression)(i))

        x.assertEq(expr, input)
    end,
    "Iterative expression parser",
    function ()
        local number = LuaEater.map(LuaEater.digit1, tonumber)
        local operator = LuaEater.one_of("+-*/")
        local expression = LuaEater.separated_pair(
            number,
            LuaEater.multispace0,
            LuaEater.maybe(operator)
        )

        local statement = LuaEater.many0(LuaEater.preceded(LuaEater.multispace0, expression))

        local input = "1 + 2 * 3 / 4 - 5"
        local i = LuaEater.input(input)
        local _, expr, tree = x.assert(LuaEater.recognize(statement)(i))

        x.assertEq(expr, input)

        x.assertDeepEq(tree, {{1, '+'}, {2, '*'}, {3, "/"}, {4, '-'}, {5, nil}})

        for i = 1, #tree do
            local expr = tree[i]
            if type(expr) == "number" then
                print(expr)
            else
                print(expr[1], expr[2])
            end
        end
    end
}