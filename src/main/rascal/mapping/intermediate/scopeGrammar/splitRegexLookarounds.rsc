module mapping::intermediate::scopeGrammar::splitRegexLookarounds

import regex::Regex;

@doc {
    Splits lookarounds into concatenations of empty body lookarounds. E.g:
    ```
    a!<b>c
    ```
    =>
    ```
    (a!<)b(>c)
    ```
}
Regex splitRegexLookarounds(Regex regex) 
    = visit(regex) {
        case lookahead(r, la) => concatenation(r, lookahead(empty(), la))
            when r != empty()
        case \negative-lookahead(r, la) => concatenation(r, \negative-lookahead(empty(), la))
            when r != empty()
        case lookbehind(r, lb) => concatenation(lookbehind(empty(), lb), r)
            when r != empty()
        case \negative-lookbehind(r, lb) => concatenation(\negative-lookbehind(empty(), lb), r)
            when r != empty()
    };