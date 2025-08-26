local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
    "Take stops at EOF",
    function ()
        local i = LuaEater.input("")
        x.assertNot(LuaEater.take(1)(i))
    end,
    "Many0 allows no matches",
    function ()
        local i = LuaEater.input("")
        local _, empty = LuaEater.many0(LuaEater.take(5))(i)
        x.assertEq(#empty, 0)
    end,
    "Many1",
    function ()
        local i = LuaEater.input("abcabcabcabcabc")
        local _, abcs = LuaEater.many1(LuaEater.take(3))(i)
        for _, abc in ipairs(abcs) do
            x.assertEq(abc, "abc")
        end
    end,
    "Many1 errors when no match",
    function ()
        local i = LuaEater.input("Alphabetic")
        x.assertNot(LuaEater.many1(LuaEater.one_of("0123456789"))(i))
    end,
    "ManyMN",
    function ()
        local function abc_1_3(input)
            input = LuaEater.input(input)
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
            input = LuaEater.input(input)
            local _, list = split_comma(input)
            return list
        end

        x.assertShallowEq(parser("abc,123,xyz"), {"abc", "123", "xyz"})
        x.assertShallowEq(parser("x,,z"), {"x", "", "z"})
        x.assertShallowEq(parser(",,"), {"", "", ""})
    end
}