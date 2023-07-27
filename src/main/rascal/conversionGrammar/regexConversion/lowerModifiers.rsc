module conversionGrammar::regexConversion::lowerModifiers

import IO;

import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::liftScopes;
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
ConvProd lowerModifiers(p:convProd(symb, parts, _)) {
    newParts = visit(parts) {
        case follow(regexp(a), regexp(b)) => regexp(liftScopes(lookahead(a, b)))
        case notFollow(regexp(a), regexp(b)) => regexp(liftScopes(\negative-lookahead(a, b)))
        case precede(regexp(a), regexp(b)) => regexp(liftScopes(lookbehind(a, b)))
        case notPrecede(regexp(a), regexp(b)) => regexp(liftScopes(\negative-lookbehind(a, b)))
        case delete(regexp(a), regexp(b)) => regexp(liftScopes(subtract(a, b)))
        case atEndOfLine(regexp(a)) => regexp(liftScopes(concatenation(a, eolRegex())))
        case atStartOfLine(regexp(a)) => regexp(liftScopes(concatenation(solRegex(), a)))
    };
    if(newParts==parts) return p;
    return convProd(symb, newParts, {convProdSource(p)});
}