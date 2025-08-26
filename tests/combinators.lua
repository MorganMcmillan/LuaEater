local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
    "All",
    function ()
        local _, output = assert(LuaEater.all{LuaEater.alpha1, LuaEater.digit1}("abc123"))
        x.assertEq(output[1], "abc")
        x.assertEq(output[2], "123")
    end,
    "Any",
    function ()
        local _, output = assert(LuaEater.any{LuaEater.alpha1, LuaEater.digit1}("123"))
        x.assertEq(output, "123")
    end,
    "Pair",
    function ()
        local _, pair = LuaEater.pair(LuaEater.alpha1, LuaEater.digit1)("abc123")
        x.assertShallowEq(pair, {"abc", "123"})
    end,
    "Separated Pair and Map",
    function ()
        local number = LuaEater.map(LuaEater.digit1, tonumber)
        local _, numbers = LuaEater.separated_pair(number, LuaEater.tag("|"), number)("123|456")
        x.assertShallowEq(numbers, {123, 456})
    end,
    "Conditional Parsing",
    function ()
        local i, parsed = LuaEater.cond(true, LuaEater.tag("abc"))("abc123")
        x.assertEq(parsed, "abc")
        i, parsed = LuaEater.cond(false, LuaEater.tag("123"))(i)
        x.assertEq(#i, 3)
        x.assertNil(parsed)
    end,
    "Map Parser",
    function ()
        local _, hello = LuaEater.map_parser(
            LuaEater.preceded(LuaEater.take(3), LuaEater.take_until("%d")),
            LuaEater.map(
                LuaEater.separated_list(LuaEater.take(1), LuaEater.tag(",")),
                table.concat
            )
        )("abch,e,l,l,o123")
        x.assertEq(hello, "hello")
    end,
    "Preceded",
    function ()
        -- Our input "test" is preceded by an arbitrary amount of space
        local _, tag = LuaEater.preceded(LuaEater.space0, LuaEater.alpha1)("   test")
        x.assertEq(tag, "test")
    end,
    "Terminated",
    function ()
        -- Parse a hello world program in C, a language famous for its semicolons.
        local _, c = LuaEater.terminated(LuaEater.take_until(";"), LuaEater.tag(";"))('printf("Hello, World!"); // Ending comment')
        x.assertEq(c, 'printf("Hello, World!")')
    end,
    "Delimited and Separated List",
    function ()
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

        local _, list = x.assert(parenthesized_list("(foo, bar, baz)"))
        x.assertShallowEq(list, {"foo", "bar", "baz"})
    end,
    "Escaped",
    function ()
        local i, escaped = LuaEater.escaped(
            LuaEater.digit1,
            LuaEater.tag("$"),
            LuaEater.tag("abc")
        )("12$abc34def")
        local _, def = LuaEater.rest(i)
        x.assertEq(escaped, "12$abc34")
        x.assertEq(def, "def")
    end,
    "Escaped List",
    function ()
        local _, escaped = LuaEater.escaped_list(
            LuaEater.alpha1,
            LuaEater.tag("/"),
            LuaEater.one_of("ntr")
        )("hello/r/n/tworld")
        x.assertShallowEq(escaped, {
            "hello", "/", "r",
            "", "/", "n",
            "", "/", "t",
            "world"
        })
    end,
    "Escaped Transform",
    function ()
        local string_chars = LuaEater.take_until{
            ['"'] = true,
            ['\\'] = true
        }
        local escaped_string = LuaEater.delimited(
            LuaEater.tag('"'),
            LuaEater.escaped_transform(
                string_chars,
                LuaEater.tag("\\"),
                LuaEater.map(LuaEater.one_of("ntr"), {
                    n = "\n",
                    t = "\t",
                    r = "\r"
                })
            ),
            LuaEater.tag('"')
        )
        local rest, escaped = escaped_string('"hello\\r\\n\\tworld"foo bar')
        x.assertEq(escaped, "hello\r\n\tworld")
        x.assertEq(rest, "foo bar")
    end,
    "Escaped Transform List",
    function ()
        local string_chars = LuaEater.take_until{
            ['"'] = true,
            ['\\'] = true
        }
        local escaped_string = LuaEater.delimited(
            LuaEater.tag('"'),
            LuaEater.escaped_transform_list(
                string_chars,
                LuaEater.tag("\\"),
                LuaEater.map(LuaEater.one_of("ntr"), {
                    n = "\n",
                    t = "\t",
                    r = "\r"
                })
            ),
            LuaEater.tag('"')
        )
        local _, escaped = escaped_string('"hello\\r\\n\\tworld"foo bar')
        x.assertShallowEq(escaped, {
            "hello", "\r",
            "", "\n",
            "", "\t",
            "world"
        })
    end
}