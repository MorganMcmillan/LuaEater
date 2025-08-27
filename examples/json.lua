local LuaEater = require("LuaEater")
local x = require("tests/xtest")

local sp = LuaEater.multispace0

local null = LuaEater.value(LuaEater.tag"null", nil)

local string = LuaEater.delimited(
    LuaEater.tag'"',
    LuaEater.escaped_transform(
        LuaEater.take_until{['"'] = true, ["\\"] = true},
        LuaEater.tag'\\',
        LuaEater.map(
            LuaEater.one_of("ntr"),
            {
                n = "\n",
                t = "\t",
                r = "\r"
            }
        )
    ),
    LuaEater.tag'"'
)

local boolean = LuaEater.any{
    LuaEater.value(LuaEater.tag"true", true),
    LuaEater.value(LuaEater.tag"false", false)
}

local number = LuaEater.verify_map(LuaEater.recognize(LuaEater.all{
    LuaEater.digit1,
    LuaEater.maybe(LuaEater.pair(
        LuaEater.tag'.',
        LuaEater.digit0
    )),
    LuaEater.maybe(LuaEater.pair(
        LuaEater.tag'e',
        LuaEater.digit1
    ))
}), tonumber)

function array(input)
    return LuaEater.delimited(
        LuaEater.tag'[',
        LuaEater.separated_list(
            value,
            LuaEater.preceded(sp, LuaEater.tag',')
        ),
        LuaEater.preceded(sp, LuaEater.tag']')
    )(input)
end

function key_value(input)
    return LuaEater.separated_pair(
        LuaEater.preceded(sp, string),
        LuaEater.preceded(sp, LuaEater.tag':'),
        value
    )(input)
end

local function kvs_to_table(kvs)
    local table = {}
    for _, kv in ipairs(kvs) do
        table[kv[1]] = kv[2]
    end
    return table
end

local object = LuaEater.map(LuaEater.delimited(
    LuaEater.tag'{',
    LuaEater.separated_list(key_value, LuaEater.preceded(sp, LuaEater.tag',')),
    LuaEater.tag'}'
), kvs_to_table)

function value(input)
    return LuaEater.preceded(sp, LuaEater.any{
        boolean,
        string,
        number,
        object,
        array,
        null
    })(input)
end

local root = LuaEater.delimited(
    sp,
    LuaEater.any{
        object,
        array,
        null
    },
    sp
)

local bool_list = LuaEater.separated_list(boolean, LuaEater.tag",")
local _, output = root('{"foo": [123, [456], 789, true]}')

x.assertDeepEq(output, {foo = {123, {456}, 789, true}})