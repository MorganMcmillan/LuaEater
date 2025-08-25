local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
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