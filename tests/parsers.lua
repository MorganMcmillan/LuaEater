local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
    "Tag",
    function ()
        local i, tag = LuaEater.tag("abc")("abc123")
        x.assertEq(tag, "abc")
        i, tag = LuaEater.tag("123")(i)
        x.assertEq(tag, "123")
    end,
    "Tag (case insensitive)",
    function ()
        local i, tag = LuaEater.tag_case_insensitive("AbC")("aBc123")
        x.assertEq(tag, "aBc")
    end,
    "Eof",
    function ()
        local rest, output = x.assert(LuaEater.rest("abc123"))
        x.assert(LuaEater.eof(rest))
        print(output, rest:left())
    end,
    "Left and Take",
    function ()
        local rest = x.assert(LuaEater.take(6)("abc123"))
        x.assertEq(#rest, 0)
    end,
    "Take errors when n is larger than input size",
    function ()
        x.assertNot(LuaEater.take(7)("abc123"))
    end,
    "Rest is all consuming",
    function ()
        x.assert(LuaEater.all_consuming(LuaEater.rest)("abc123"))
    end,
    "All consuming fails when there's input left",
    function ()
        x.assertNot(LuaEater.all_consuming(LuaEater.success)("abc123"))
    end,
    "Multiple space and lines",
    function ()
        for _, input in ipairs{"local x=123", "local x = 123", "local     \t x  =\n\n123"} do
            local _, output = assert(LuaEater.all{
                LuaEater.tag"local",
                LuaEater.preceded(LuaEater.multispace1, LuaEater.alphanumeric1),
                LuaEater.preceded(LuaEater.multispace0, LuaEater.tag"="),
                LuaEater.preceded(LuaEater.multispace0, LuaEater.digit1),
                LuaEater.eof
            }("local x=123"))

            x.assertEq(output[1], "local")
            x.assertEq(output[2], "x")
            x.assertEq(output[3], "=")
            x.assertEq(output[4], "123")
        end
    end,
    "One of",
    function ()
        x.assert(LuaEater.all_consuming(LuaEater.many0(LuaEater.one_of("dcba")))("abcd"))
    end,
}