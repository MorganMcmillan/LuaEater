local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
    "All",
    function ()
        local i = LuaEater.input("abc123")
        local _, output = assert(LuaEater.all{LuaEater.alpha1, LuaEater.digit1}(i))
        x.assertEq(output[1], "abc")
        x.assertEq(output[2], "123")
    end,
    "Any",
    function ()
        local i = LuaEater.input("123")
        local _, output = assert(LuaEater.any{LuaEater.alpha1, LuaEater.digit1}(i))
        x.assertEq(output, "123")
    end,
    "Pair",
    function ()
        local i = LuaEater.input("abc123")
        local _, pair = LuaEater.pair(LuaEater.alpha1, LuaEater.digit1)(i)
        x.assertShallowEq(pair, {"abc", "123"})
    end,
    "Separated Pair and Map",
    function ()
        local i = LuaEater.input("123|456")
        local number = LuaEater.map(LuaEater.digit1, tonumber)
        local _, numbers = LuaEater.separated_pair(number, LuaEater.tag("|"), number)(i)
        x.assertShallowEq(numbers, {123, 456})
    end,
    "Conditional Parsing",
    function ()
        local i = LuaEater.input("abc123")
        local i, parsed = LuaEater.cond(true, LuaEater.tag("abc"))(i)
        x.assertEq(parsed, "abc")
        i, parsed = LuaEater.cond(false, LuaEater.tag("123"))(i)
        x.assertEq(i:left(), 3)
        x.assertNil(parsed)
    end,
    "Map Parser",
    function ()
        local i = LuaEater.input("abch,e,l,l,o123")
        local _, hello = LuaEater.map_parser(
            LuaEater.preceded(LuaEater.take(3), LuaEater.take_until("%d")),
            LuaEater.map(
                LuaEater.separated_list(LuaEater.take(1), LuaEater.tag(",")),
                table.concat
            )
        )(i)
        x.assertEq(hello, "hello")
    end,
    "Preceded",
    function ()
        -- Our input "test" is preceded by an arbitrary amount of space
        local i = LuaEater.input("   test")
        local _, tag = LuaEater.preceded(LuaEater.space0, LuaEater.alpha1)(i)
        x.assertEq(tag, "test")
    end,
    "Terminated",
    function ()
        -- Parse a hello world program in C, a language famous for its semicolons.
        local i = LuaEater.input('printf("Hello, World!");')
        local _, c = LuaEater.terminated(LuaEater.take_until(";"), LuaEater.tag(";"))(i)
        x.assertEq(c, 'printf("Hello, World!")')
    end,
    "Delimited and Separated List",
    function ()
        local i = LuaEater.input("(foo, bar, baz)")
        local comma = LuaEater.all{
            LuaEater.space0,
            LuaEater.tag(","),
            LuaEater.space0
        }
        local parenthesized_list = LuaEater.delimited(
            LuaEater.tag("("),
            LuaEater.separated_list(LuaEater.alpha1, comma),
            LuaEater.tag(")")
        )

        local _, list = x.assert(parenthesized_list(i))
        x.assertShallowEq(list, {"foo", "bar", "baz"})
    end,
    "Escaped",
    function ()
        local i = LuaEater.input("12$abc34def")
        local i, escaped = LuaEater.escaped(
            LuaEater.digit1,
            LuaEater.tag("$"),
            LuaEater.tag("abc")
        )(i)
        local _, def = LuaEater.rest(i)
        x.assertEq(escaped, "12$abc34")
        x.assertEq(def, "def")
    end,
    "Escaped List",
    function ()
        local i = LuaEater.input("hello/r/n/tworld")
        local _, escaped = LuaEater.escaped_list(
            LuaEater.alpha1,
            LuaEater.tag("/"),
            LuaEater.one_of("ntr")
        )(i)
        x.assertShallowEq(escaped, {
            "hello", "/", "r",
            "", "/", "n",
            "", "/", "t",
            "world"
        })
    end
}