# LuaEater: a Parser Combinator Library for Lua

LuaEater is a parsing libary inspired by Rust's [Nom](https://github.com/rust-bakery/nom). Instead of writing parsers in a separate file, they are constructed using functions.

A parser is a function that takes in a string as an input and returns the remain input and the item that was parsed, usually also a string.

# Example

[JSON](https://www.json.org/json-en.html) parser:
```Lua
local LuaEater = require("LuaEater")

local sp = LuaEater.multispace0

local null = LuaEater.value(LuaEater.tag"null", nil)

local string = LuaEater.delimited(
    LuaEater.tag'"',
    LuaEater.escaped_transform(
        LuaEater.take_until{['"'] = true, ["\\"] = true},
        LuaEater.tag'\\',
        LuaEater.map(
            LuaEater.one_of('ntr"'),
            {
                n = "\n",
                t = "\t",
                r = "\r",
                ['"'] = '"'
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
    LuaEater.maybe(LuaEater.tag"-"),
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
    LuaEater.preceded(sp, LuaEater.tag'}')
), kvs_to_table)

function value(input)
    return LuaEater.context("Value", LuaEater.preceded(sp, LuaEater.any{
        boolean,
        string,
        number,
        object,
        array,
        null
    }))(input)
end

local root = LuaEater.context("Root", LuaEater.delimited(
    sp,
    LuaEater.any{
        object,
        array,
        null
    },
    sp
))
```

# List of Combinators

## Character Sequence Combinators

| Combinator           | Parameters                                                                                               | Explanation                                                                    |
| -------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| char                 | c: string                                                                                                | Matches a single character                                                     |
| tag                  | tag: string                                                                                              | Matches a sequence of characters                                               |
| tag_case_insensitive | tag: string                                                                                              | Matches a sequence of characters without case sensitivity                      |
| match                | pattern: string                                                                                          | Thin wrapper around string.match                                               |
| one_of               | chars: string                                                                                            | Matches a character if it's in the set of characters.                          |
| none_of              | chars: string                                                                                            | Matches a character if it's not in the set of characters.                      |
| take                 | n: integer                                                                                               | Matches n characters                                                           |
| take_while           | cond: function(c: char): boolean \| table{string = true} \| string (pattern)                             | Matches characters while a condition returns true                              |
| take_while_m_n       | min: integer, max: integer, cond: function(c: char): boolean \| table{string = true} \| string (pattern) | Matches characters between min and max times or while a condition returns true |
| take_until           | cond: function(c: char): boolean \| table{string = true} \| string (pattern)                             | Matches characters while a condition returns false                             |
| rest                 |                                                                                                          | Returns the rest of the input                                                  |
| eof                  |                                                                                                          | Checks that the input has reached its end                                      |

## Combining Parsers

| Combinator     |     |
| -------------- | --- |
| preceded       |     |
| terminated     |     |
| delimited      |     |
| pair           |     |
| separated_pair |     |
| any            |     |
| all            |     |

## Changing the Output of Parsers

| Combinator    |                               | Explanation                                                                              |
| ------------- | ----------------------------- | ---------------------------------------------------------------------------------------- |
| value         |                               | If a parser succeeds then it returns the specified value                                 |
| map           |                               | Maps the result of parser to a function                                                  |
| map_parser    |                               | Maps the result of a parser onto another parser                                          |
| verify        |                               | Verifies that a parser meets a condition                                                 |
| verify_map    |                               | Verifies that a parser meets a condition and returns the result of that verification     |
| cond          | cond: boolean, parser: Parser | Conditionally applies a parser                                                           |
| maybe         |                               | Optionally applies a parser                                                              |
| invert        |                               | Returns an error if the parser was ok                                                    |
| either        |                               | Selects a value based on whether the parser was successful or not                        |
| peek          |                               | Applies a parser without consuming any input                                             |
| recognize     |                               | Applies a parser and returns its consumed input as a string, along with its actual value |
| all_consuming |                               | Ensures that a parser consumes its entire input                                          |

## Applying Parsers Multiple Times

| Combinator             |     |
| ---------------------- | --- |
| many0                  |     |
| many1                  |     |
| many_m_n               |     |
| many_till              |     |
| separated_list         |     |
| escaped                |     |
| escaped_list           |     |
| escaped_transform      |     |
| escaped_transform_list |     |
| length_value           |     |

## Premade Parsers

| Parser                        | Explanation                                     |
| ----------------------------- | ----------------------------------------------- |
| alpha0 / alpha1               |                                                 |
| alphanumeric0 / alphanumeric1 |                                                 |
| digit0 / digit1               |                                                 |
| bin_digit0 / bin_digit1       |                                                 |
| oct_digit0 / oct_digit1       |                                                 |
| hex_digit0 / hex_digit1       |                                                 |
| space0 / space1               | Parses (non-line-ending) whitespace             |
| multispace0 / multispace1     | Parses whitespace                               |
| crlf                          | Parses a carriage return and line feed sequence |
| newline                       | Parses a line feed character                    |
| tab                           | Parses a tab character                          |

## Character Tables

LuaEater has a character table feature where a single character gets mapped onto a specific parser. This is mainly implemented as an optimization to prevent multiple different parsers from being tried before the correct one is found.

Character tables are constructed with `LuaEater.CharTable:new()`, optionally taking in a premade table of characters to parsers. Character tables are called just like regular parsers and can be used in combinators.

Several helper builder methods are implemented to help with the construction of character tables. Each takes in a parser and returns itself. Some methods already have a default parser in place, which usually just parses multiple of its character type.

| Method          | Explanation                                               |
| --------------- | --------------------------------------------------------- |
| alphabetic      | Characters a-Z                                            |
| alphanumeric    | Characters a-Z 0-9 and _                                  |
| numeric         | Characters 0-9                                            |
| lower           | Lowercase characters a-z                                  |
| upper           | Uppercase characters A-Z                                  |
| whitespace      | Any whitespace character                                  |
| punctuation     | Characters \`~,<.>/?!@#$%^&\*()-+=[{]}\\\|;:'"            |
| quotation       | Characters \`'"                                           |
| null            | \0                                                        |
| set(characters) | Sets each character in the string to the specified parser |

# Related Projects

- [LPeg](http://www.inf.puc-rio.br/~roberto/lpeg/) - Parsing expression grammars for Lua.
