module conversion::regexConversion::concatenateRegexes

import List;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::liftScopes;
import conversion::util::RegexCache;
import regex::Regex;
import regex::PSNFA;

@doc {
    Tries to apply the concatenation rule:
    ```
    A -> x X Y y         
    ```
    => {Concatenation}
    ```
    A -> x (X Y) y
    ```
    
    Internally applies the rules:
    - Scope lifting

    This is done exhasutively for this set of productions.
}
set[ConvProd] concatenateRegexes(set[ConvProd] productions) 
    = {concatenateRegexes(production) | production <- productions};

@doc {
    Tries to apply the concatenation rule:
    ```
    A -> x X Y y         
    ```
    => {Concatenation}
    ```
    A -> x (X Y) y
    ```

    Internally applies the rules:
    - Scope lifting

    This is done exhasutively for this production.
}
ConvProd concatenateRegexes(p:convProd(symb, parts, _)) {
    list[ConvSymbol] newParts = [];
    list[Regex] regexes = [];
    void flush(){
        if(size(regexes)>0) {
            if([r] := regexes)
                newParts += regexp(r);
            else 
                newParts += regexp(liftScopes(reduceConcatenation(concatenation(regexes))));
            regexes = [];
        }
    }

    for(part <- parts) {
        if(regexp(r) := part) {
            regexes += r;

            // Regular expressions can only span one line, so we can't add anything after a newline character
            if(containsNewline(r))
                flush();
        } else {
            flush();
            newParts += part;
        }
    }
    flush();
    return convProd(symb, newParts, {convProdSource(p)});
}