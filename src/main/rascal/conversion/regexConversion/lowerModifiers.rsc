module conversion::regexConversion::lowerModifiers

import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::liftScopes;
import regex::RegexCache;
import regex::RegexProperties;
import regex::Regex;

@doc {
    Tries to apply modifier lowering, putting modifiers on the regex level, if possible:
    ```
    A -> x X >> Y y
    ```
    => {Modifier lowering}
    ```
    A -> x (X > Y) y
    ```

    Internally applies the rules:
    - Scope lifting

    This is done exhaustively for the given production
}
ConvProd lowerModifiers(p:convProd(symb, parts)) {
    newParts = visit(parts) {
        case follow(regexp(a), regexp(b)) => regexp(liftScopes(lookahead(a, b)))
            when !containsNewline(a)
        case notFollow(regexp(a), regexp(b)) => regexp(liftScopes(\negative-lookahead(a, b)))
            when !containsNewline(a)
        case precede(regexp(a), regexp(b)) => regexp(liftScopes(lookbehind(a, b)))
            when !containsNewline(b)
        case notPrecede(regexp(a), regexp(b)) => regexp(liftScopes(\negative-lookbehind(a, b)))
            when !containsNewline(b)
        case delete(regexp(a), regexp(b)) => regexp(liftScopes(subtract(a, b)))
        case atEndOfLine(regexp(a)) => regexp(liftScopes(concatenation(a, eolRegex())))
            when !containsNewline(a)
        case atStartOfLine(regexp(a)) => regexp(liftScopes(concatenation(solRegex(), a))) // Should be fine regarding newlines, since SOL also includes SOF detection, which is what TM considers the start of the line to be
    };
    if(newParts==parts) return p;
    return convProd(symb, newParts);
}