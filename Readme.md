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

| Combinator           | Parameters                                                                                               | Explanation                                                                     |
| -------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| char                 | c: string                                                                                                | Matches a single character.                                                     |
| tag                  | tag: string                                                                                              | Matches a sequence of characters.                                               |
| tag_case_insensitive | tag: string                                                                                              | Matches a sequence of characters without case sensitivity.                      |
| match                | pattern: string                                                                                          | Thin wrapper around string.match.                                               |
| one_of               | chars: string                                                                                            | Matches a character if it's in the set of characters.                           |
| none_of              | chars: string                                                                                            | Matches a character if it's not in the set of characters.                       |
| take                 | n: integer                                                                                               | Matches n characters.                                                           |
| take_while           | cond: function(c: char): boolean \| table{string = true} \| string (pattern)                             | Matches characters while a condition returns true.                              |
| take_while_m_n       | min: integer, max: integer, cond: function(c: char): boolean \| table{string = true} \| string (pattern) | Matches characters between min and max times or while a condition returns true. |
| take_until           | cond: function(c: char): boolean \| table{string = true} \| string (pattern)                             | Matches characters while a condition returns false.                             |
| rest                 |                                                                                                          | Returns the rest of the input.                                                  |
| eof                  |                                                                                                          | Checks that the input has reached its end.                                      |

## Combining Parsers

| Combinator     | Parameters                                   | Explanation                                                                    |
| -------------- | -------------------------------------------- | ------------------------------------------------------------------------------ |
| preceded       | precedent: Parser, parser: Parser            | Runs precedent, then returns the result of parser.                             |
| terminated     | parser: Parser, terminator: Parser           | Returns the result of parser if it is followed by the terminator.              |
| delimited      | first: Parser, second: Parser, third: parser | Runs each parser and returns the result of the second. Useful for parenthisis. |
| pair           | first: Parser, second: Parser                | Returns the result of both parsers.                                            |
| separated_pair | first: Parser, sep: Parser, second: Parser   | Returns the result of both parsers separated by sep.                           |
| any            | parsers: {Parser}                            | Returns the result of the first successful parser.                             |
| all            | parsers: {Parser}                            | Returns the results of each parser in sequence, provided none of them error.   |

## Changing the Output of Parsers

| Combinator    | Parameters                          | Explanation                                                                               |
| ------------- | ----------------------------------- | ----------------------------------------------------------------------------------------- |
| value         | parser: Parser, value: any          | If a parser succeeds then it returns the specified value.                                 |
| map           | parser: Parser, f: function         | Maps the result of parser to a function.                                                  |
| map_parser    | outer: Parser, inner: Parser        | Maps the result of a parser onto another parser.                                          |
| verify        | parser: Parser, predicate: function | Verifies that a parser meets a condition.                                                 |
| verify_map    | parser: Parser, predicate: function | Verifies that a parser meets a condition and returns the result of that verification.     |
| cond          | cond: boolean, parser: Parser       | Conditionally applies a parser.                                                           |
| maybe         | parser: Parser                      | Optionally applies a parser.                                                              |
| invert        | parser: Parser                      | Returns an error if the parser was ok.                                                    |
| either        | parser: Parser, ok: any, err: any   | Selects a value based on whether the parser was successful or not.                        |
| peek          | parser: Parser                      | Applies a parser without consuming any input.                                             |
| recognize     | parser: Parser                      | Applies a parser and returns its consumed input as a string, along with its actual value. |
| all_consuming | parser: Parser                      | Ensures that a parser consumes its entire input.                                          |

## Applying Parsers Multiple Times

| Combinator             | Parameters                                         | Explanation                                                                                                                                                       |
| ---------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| many0                  | parser: Parser                                     | Applies a parser 0 or more times.                                                                                                                                 |
| many1                  | parser: Parser                                     | Applies a parser 1 or more times.                                                                                                                                 |
| many_m_n               | min: integer, max: integer, parser: Parser         | Applies a parser between min and max times.                                                                                                                       |
| many_till              | parser: Parser, till: Parser                       | Applies a parser until till returns ok.                                                                                                                           |
| separated_list         | parser: Parser, sep: Parser                        | Applies a parser 0 or more times, separated by sep.                                                                                                               |
| escaped                | normal: Parser, control: Parser, escapable: Parser | Parses a sequence of characters containing escape characters.                                                                                                     |
| escaped_list           | normal: Parser, control: Parser, escapable: Parser | Parses a sequence of characters containing escape characters, collecting each separated escape sequence into an array.                                            |
| escaped_transform      | normal: Parser, control: Parser, escapable: Parser | Parses a sequence of characters containing escape characters and maps them onto the result of escapable.                                                          |
| escaped_transform_list | normal: Parser, control: Parser, escapable: Parser | Parses a sequence of characters containing escape characters and maps them onto the result of escapable, collecting each separated escape sequence into an array. |
| length_value           | count: Parser, parser: Parser                      | Parses a length using count and then applies parser exactly that many times.                                                                                      |

## Premade Parsers

| Parser                        | Explanation                                     |
| ----------------------------- | ----------------------------------------------- |
| alpha0 / alpha1               | Parses alphabetic characters a-Z                |
| alphanumeric0 / alphanumeric1 | Parses alphanumeric characters a-Z 0-9 and _    |
| digit0 / digit1               | Parses digit characters 0-9                     |
| bin_digit0 / bin_digit1       | Parses binary characters 0 and 1                |
| oct_digit0 / oct_digit1       | Parses octal characters 0-7                     |
| hex_digit0 / hex_digit1       | Parses hexadecimal characters 0-9 a-f A-F       |
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
