local LuaEater = require("LuaEater")
local x = require("tests/xtest")

local function second(a, b)
    return b
end

x.run{
    "Take stops at EOF",
    function ()
        x.assertNot(LuaEater.take(1)(""))
    end,
    "Many0 allows no matches",
    function ()
        local _, empty = LuaEater.many0(LuaEater.take(5))("")
        x.assertEq(#empty, 0)
    end,
    "Many1",
    function ()
        local _, abcs = LuaEater.many1(LuaEater.take(3))("abcabcabcabcabc")
        for _, abc in ipairs(abcs) do
            x.assertEq(abc, "abc")
        end
    end,
    "Many1 errors when no match",
    function ()
        x.assertNot(LuaEater.many1(LuaEater.one_of("0123456789"))("Alphabetic"))
    end,
    "ManyMN",
    function ()
        local function abc_1_3(input)
            local _, abcs = LuaEater.many_m_n(1, 3, LuaEater.tag("abc"))(input)
            return abcs
        end

        x.assertEq(#abc_1_3("abcabcabc"), 3)
        x.assertEq(#abc_1_3("abcabcabcabc"), 3)
        x.assertEq(#abc_1_3("abc123"), 1)
        x.assertEq(#abc_1_3("abcabc123"), 2)
        x.assertString(abc_1_3("123abc")) -- Error message
    end,
    "Comma Separated List",
    function ()
        local comma = LuaEater.all{
            LuaEater.multispace0,
            LuaEater.tag(","),
            LuaEater.multispace0
        }
        local not_comma = LuaEater.any{
            LuaEater.alphanumeric1,
            LuaEater.value(LuaEater.skip(1), "")
        }
        local split_comma = LuaEater.separated_list(not_comma, comma)
        local function parser(input)
            local _, list = split_comma(input)
            return list
        end

        x.assertShallowEq(parser("abc,123,xyz"), {"abc", "123", "xyz"})
        x.assertShallowEq(parser("x,,z"), {"x", "", "z"})
        x.assertShallowEq(parser(",,"), {"", "", ""})
    end,
    "Length Value",
    function ()
        local number = LuaEater.map(LuaEater.digit1, tonumber)
        local length_list = LuaEater.length_value(
            LuaEater.terminated(number, LuaEater.tag(":")),
            LuaEater.preceded(LuaEater.multispace1, number)
        )

        print(length_list("4: 1 2 3 4"))

        x.assertShallowEq(second(length_list(i)), {1, 2, 3, 4})
    end
}