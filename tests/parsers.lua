local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
    "Tag",
    function ()
        local i = LuaEater.input("abc123")
        local i, tag = LuaEater.tag("abc")(i)
        x.assertEq(tag, "abc")
        i, tag = LuaEater.tag("123")(i)
        x.assertEq(tag, "123")
    end,
    "Tag (case insensitive)",
    function ()
        local i = LuaEater.input("aBc123")
        local i, tag = LuaEater.tag_case_insensitive("AbC")(i)
        x.assertEq(tag, "aBc")
    end,
    "Eof",
    function ()
        local i = LuaEater.input("abc123")
        local rest, output = x.assert(LuaEater.rest(i))
        x.assert(LuaEater.eof(rest))
        print(output, rest:left())
    end,
    "Left and Take",
    function ()
        local i = LuaEater.input("abc123")
        print(i:left())
        local rest = x.assert(LuaEater.take(6)(i))
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
        x.assert(LuaEater.all_consuming(LuaEater.rest)(i))
    end,
    "All consuming fails when there's input left",
    function ()
        local i = LuaEater.input("abc123")
        x.assertNot(LuaEater.all_consuming(LuaEater.success)(i))
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
}