local LuaEater = require("LuaEater")
local x = require("tests/xtest")

x.run{
    "The Ultimate Test:",
    "Parsing Lua",
    function ()
        -- We start by defining the lowest level of syntax for our language, and gradually building up by combining pieces together.
        local keyword = {
            ["and"] = LuaEater.tag("and"),
            ["break"] = LuaEater.tag("break"),
            ["do"] = LuaEater.tag("do"),
            ["else"] = LuaEater.tag("else"),
            ["elseif"] = LuaEater.tag("elseif"),
            ["end"] = LuaEater.tag("end"),
            ["false"] = LuaEater.tag("false"),
            ["for"] = LuaEater.tag("for"),
            ["function"] = LuaEater.tag("function"),
            ["if"] = LuaEater.tag("if"),
            ["in"] = LuaEater.tag("in"),
            ["local"] = LuaEater.tag("local"),
            ["nil"] = LuaEater.tag("nil"),
            ["not"] = LuaEater.tag("not"),
            ["or"] = LuaEater.tag("or"),
            ["repeat"] = LuaEater.tag("repeat"),
            ["return"] = LuaEater.tag("return"),
            ["then"] = LuaEater.tag("then"),
            ["true"] = LuaEater.tag("true"),
            ["until"] = LuaEater.tag("until"),
            ["while"] = LuaEater.tag("while")
        }

        local function surrounded_by_space(parser)
            return LuaEater.delimited(LuaEater.multispace0, parser, LuaEater.multispace0)
        end

        local function preceded_by_space(parser, space_type)
            return LuaEater.preceded(space_type or LuaEater.multispace0, parser)
        end

        local function all_preceded_by_space(parsers)
            local preceded_parsers = {}
            for i = 1, #parsers do
                preceded_parsers[i] = preceded_by_space(parsers[i])
            end
            return LuaEater.all(preceded_parsers)
        end
        
        --- Makes a table act as a function
        local function define(table, f)
            setmetatable(table, {__call = function (_, x)
                return f(x)
            end})
        end

        -- Deferred parsers
        local expression = {}
        local statement = {}

        local identifier = LuaEater.map(LuaEater.verify(LuaEater.all {
                    LuaEater.alpha1,
                    LuaEater.alphanumeric0
                },
                function(ident)
                    return not keyword[ident]
                end),
            function(ident)
                return { type = "identifier", value = ident }
            end)


        local boolean_true = LuaEater.value(keyword["true"], {type = "boolean", value = "true"})
        local boolean_false = LuaEater.value(keyword["false"], {type = "boolean", value = "false"})
        
        local escape_sequence = LuaEater.map

        local function string(quote_char)
            return LuaEater.delimited(
                LuaEater.tag(quote_char),
                LuaEater.escaped_transform(
                    -- Stop at quote end or escape sequence
                    LuaEater.take_until{
                        [quote_char] = true,
                        ['\\'] = true,
                    },
                    LuaEater.tag'\\',
                    escape_sequence
                ),
                LuaEater.tag(quote_char)
            )
        end

        local number = LuaEater.map(LuaEater.digit1, function (d)
            return {type = "number", value = tonumber(d)}
        end)

        local hex_number = LuaEater.map(LuaEater.hex_digit1, function (h)
            return {type = "number", value = tonumber(h, 16)}
        end)

        local bin_number = LuaEater.map(LuaEater.bin_digit1, function (b)
            return {type = "number", value = tonumber(b, 2)}
        end)

        local number_with_base = LuaEater.any{
            LuaEater.preceded(
                LuaEater.take(1), -- Guaranteed to be 0
                LuaEater.CharTable:new{
                    x = hex_number,
                    b = bin_number,
                }
            ),
            number
        }

        local function list(parser, sep)
            return LuaEater.separated_list(
                surrounded_by_space(parser),
                sep or LuaEater.tag','
            )
        end

        local parameter_list = LuaEater.delimited(
            LuaEater.tag'(',
            list(identifier),
            LuaEater.tag')'
        )

        -- Lua's whitespace also includes a semicolon
        local lua_whitespace = LuaEater.take_while{
            [";"] = true,
            [" "] = true,
            ["\r"] = true,
            ["\n"] = true,
            ["\t"] = true,
            ["\v"] = true
        }

        local lua_eof = LuaEater.preceded(lua_whitespace, LuaEater.eof)

        local prefix_expression = {}
        
        local call_operator = LuaEater.preceded(lua_whitespace, LuaEater.any{
            argument_list,
            string,
            table_definition
        })
        call_operator = LuaEater.map(call_operator, function(fn)
            if fn.type == "string" or fn.type == "table" then
                return {type = "call_operator", parameters = {fn}}
            else
                return {type = "call_operator", parameters = fn}
            end
        end)

        local function_call = LuaEater.any{
            -- Function call
            all_preceded_by_space{
                prefix_expression,
                call_operator
            },
            -- Method call
            all_preceded_by_space{
                prefix_expression,
                LuaEater.tag":",
                identifier,
                call_operator
            }
        }

        local lvalue = LuaEater.any{
            all_preceded_by_space{
                prefix_expression,
                LuaEater.tag"[",
                expression,
                LuaEater.tag"]"
            },
            LuaEater.separated_pair(
                prefix_expression,
                surrounded_by_space(LuaEater.tag"."),
                identifier
            ),
            identifier
        }

        define(prefix_expression, LuaEater.any{
            LuaEater.delimited(
                LuaEater.tag"(",
                expression,
                LuaEater.tag")"
            ),
            function_call,
            lvalue
        })

        local return_statement = LuaEater.preceded(keyword["return"], list(expression))

        return_statement = LuaEater.map(return_statement, function (ret)
            return {type = "return_statement", value = ret}
        end)

        local block = preceded_by_space(LuaEater.pair(LuaEater.separated_list(statement, lua_whitespace), preceded_by_space(return_statement, lua_whitespace)), lua_whitespace)

        local function_definition = all_preceded_by_space{
            keyword["function"],
            parameter_list,
            block,
            keyword["end"]
        }
        function_definition = LuaEater.map(function_definition, function (fn)
            return {type = "function", parameters = fn[3], value = fn[4]}
        end)

        local table_field_assignment = LuaEater.separated_pair(
            LuaEater.any{
                identifier,
                LuaEater.delimited(
                    LuaEater.tag'[',
                    surrounded_by_space(expression),
                    LuaEater.tag']'
                )
            },
            surrounded_by_space(LuaEater.tag'='),
            expression
        )

        local table_definition = LuaEater.delimited(
            LuaEater.tag'{',
            list(LuaEater.any{expression, table_field_assignment}, LuaEater.one_of",;"),
            LuaEater.tag'}'
        )

        local literal = LuaEater.CharTable:new{
            n = LuaEater.value(keyword["nil"], {type = "nil"}),
            t = boolean_true,
            f = LuaEater.any{
                boolean_false,
                function_definition
            },
            ['"'] = string('"'),
            ["'"] = string("'"),
            ["{"] = table_definition,
        }:numeric(number):set("0", number_with_base)

        local argument_list = LuaEater.delimited(
            LuaEater.tag'(',
            list(expression),
            LuaEater.tag')'
        )

        -- Statement types

        local function binary_operator_token(operator)
            return {type = "binary_operator", value = operator}
        end

        local binary_operator = LuaEater.CharTable:new()
            :set("+-*^%&|", LuaEater.map(LuaEater.take(1), binary_operator_token))
        binary_operator["/"] = LuaEater.map(LuaEater.any{
            LuaEater.tag"//",
            LuaEater.take(1)
        }, binary_operator_token)
        binary_operator["~"] = LuaEater.map(LuaEater.any{
            LuaEater.tag"~=",
            LuaEater.take(1)
        }, binary_operator_token)
        binary_operator["<"] = LuaEater.map(LuaEater.any{
            LuaEater.tag"<<",
            LuaEater.tag"<=",
            LuaEater.take(1)
        }, binary_operator_token)
        binary_operator[">"] = LuaEater.map(LuaEater.any{
            LuaEater.tag">>",
            LuaEater.tag">=",
            LuaEater.take(1)
        }, binary_operator_token)
        binary_operator["="] = LuaEater.map(
            LuaEater.tag"==",
            binary_operator_token
        )
        binary_operator["."] = LuaEater.map(
            LuaEater.tag"..",
            binary_operator_token
        )
        binary_operator["a"] = LuaEater.map(
            LuaEater.tag"and",
            binary_operator_token
        )
        binary_operator["o"] = LuaEater.map(
            LuaEater.tag"or",
            binary_operator_token
        )

        local function unary_operator_token(operator)
            return {type = "unary_operator", value = operator}
        end

        local unary_operator = LuaEater.CharTable:new()
            :set("-#~", LuaEater.map(LuaEater.take(1), unary_operator_token))
        unary_operator["n"] = LuaEater.map(
            LuaEater.tag"not",
            unary_operator_token
        )

        local break_statement = keyword["break"]

        local function_statement = all_preceded_by_space{
            LuaEater.maybe(keyword["local"]),
            keyword["function"],
            identifier,
            parameter_list,
            block,
            keyword["end"]
        }

        local do_block = LuaEater.delimited(
            preceded_by_space(keyword["do"]),
            preceded_by_space(block),
            preceded_by_space(keyword["end"])
        )

        local while_statement = all_preceded_by_space{
            keyword["while"],
            expression,
            keyword["do"],
            block,
            keyword["end"]
        }

        local repeat_until_statement = all_preceded_by_space{
            keyword["repeat"],
            block,
            keyword["until"],
            expression
        }

        local if_statement = all_preceded_by_space{
            keyword["if"],
            expression,
            keyword["then"],
            block,
            LuaEater.many0(all_preceded_by_space{
                keyword["elseif"],
                expression,
                keyword["then"],
                block
            }),
            LuaEater.maybe(
                LuaEater.pair(
                    keyword["else"],
                    preceded_by_space(block)
                )
            ),
            keyword["end"]
        }

        local numeric_for_statement = all_preceded_by_space{
            keyword["for"],
            identifier,
            LuaEater.tag"=",
            expression,
            LuaEater.tag",",
            expression,
            LuaEater.maybe(
                LuaEater.preceded(
                    LuaEater.tag",",
                    preceded_by_space(expression)
                )
            ),
            keyword["do"],
            block,
            keyword["end"]
        }

        local generic_for_statement = all_preceded_by_space{
            keyword["for"],
            list(identifier),
            keyword["in"],
            list(expression),
            keyword["do"],
            block,
            keyword["end"]
        }

        local label_statement = LuaEater.delimited(
            LuaEater.tag"::",
            surrounded_by_space(identifier),
            LuaEater.tag"::"
        )

        local goto_statement = LuaEater.preceded(
            LuaEater.terminated(LuaEater.tag"goto", LuaEater.multispace1),
            identifier
        )

        local assignment_statement = LuaEater.separated_pair(
            list(identifier),
            LuaEater.tag'=',
            list(expression)
        )

        local local_assignment_statement = LuaEater.all{
            keyword["local"],
            list(identifier),
            LuaEater.maybe(
                LuaEater.preceded(
                    LuaEater.tag'=',
                    list(expression)
                )
            )
        }

        define(
            statement,
            LuaEater.any{
                local_assignment_statement,
                assignment_statement,
                break_statement,
                label_statement,
                goto_statement,
                do_block,
                while_statement,
                repeat_until_statement,
                if_statement,
                numeric_for_statement,
                generic_for_statement,
                function_statement,
                function_call
            }
        )

        -- Expression types
        local binary_expression = all_preceded_by_space{
            expression,
            binary_operator,
            expression
        }

        local unary_expression = all_preceded_by_space{
            unary_operator,
            expression
        }

        define(
            expression,
            LuaEater.any{
                prefix_expression,
                LuaEater.tag"...",
                literal,
                binary_expression,
                unary_expression
            }
        )

        -- Now for the real test.
        -- Let's see how it handles parsing hello world as a block
        local chunk = LuaEater.terminated(block, lua_eof)

        x.assert(chunk('print("hello world")'))

    end
}