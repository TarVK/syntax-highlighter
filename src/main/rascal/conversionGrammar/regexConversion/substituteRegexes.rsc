module conversionGrammar::regexConversion::substituteRegexes

import Set;
import Map;
import ParseTree;
import IO;

import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::liftScopes;
import conversionGrammar::regexConversion::concatenateRegexes;
import conversionGrammar::regexConversion::lowerModifiers;
import regex::Regex;

@doc {
    Tries to apply the substitution rule:
    ```
    A -> x (<s> B) y
    B -> X
    B -/>
    ```
    => {Substitute}
    ```
    A -> x (<s> X) y
    ```

    Internally applies the rules:
    - Concatenation
    - Scope lifting
    - Modifier lowering

    Substituions are also applied within special constructs like follow operators:
    ```
    A -> x ((<s> B) >> Y) y
    B -> X
    B -/>
    ```
    => {Substitute}
    ```
    A -> x ((<s> X) >> Y) y
    ```

    This is done exhasutively for this symbol. 
    Returns the set of affected non-terminals, and the grammar with the substitutions applied.
}
tuple[set[Symbol], ProdMap] substituteRegexes(ProdMap productions, Symbol target) {
    if(target notin productions) return <{}, productions>;

    targetProds = productions[target];
    if({p:convProd(target, [regexp(regex)], _)} := targetProds) {
        targetSource = convProdSource(p);
        set[Symbol] affected = {};

        productions = delete(productions, target);
        for(def <- productions) {
            prods = productions[def];
            
            // Note that def and lDef may be different, because of applied labels
            for(s:convProd(lDef, parts:[*_, /symb(target, _), *_],  _) <- prods) {
                list[ConvSymbol] newParts = [];
                for(part <- parts)
                    newParts += visit(part) {
                        case symb(target, scopes) => regexp(
                            size(scopes)>0
                                ? liftScopes(mark({scopeTag(scopes)}, regex))
                                : regex
                        )
                    };
                
                affected += def;
                productions[def] -= s;
                productions[def] += concatenateRegexes(lowerModifiers(
                    convProd(lDef, newParts, {targetSource, convProdSource(s)})
                ));
            }
        }
        return <affected, productions>;
    }
    
    return <{}, productions>;
}

@doc {
    Tries to apply the sequence substituion rule:
    ```
    A -> x B y
    B -> z
    B -/>
    ```
    => {Substitute sequence}
    ```
    A -> x z y
    ```

    Internally applies the rules:
    - Concatenation

    Only asubstitues on the top-level of the rule, notin special constructs like follows.

    This is done exhasutively for this symbol.
    Returns the set of affected non-terminals, and the grammar with the substitutions applied.
}
tuple[set[Symbol], ProdMap] substituteSequence(ProdMap productions, Symbol target) {
    if(target notin productions) return <{}, productions>;

    targetProds = productions[target];
    if({p:convProd(target, subParts, _)} := targetProds) {
        targetSource = convProdSource(p);
        set[Symbol] affected = {};
        canRemove = true;

        for(def <- productions) {
            prods = productions[def];

            // Note that def and lDef may be different, because of applied labels
            for(s:convProd(lDef, parts:[*_, /symb(target, []), *_],  _) <- prods) {
                list[ConvSymbol] newParts = [];
                for(part <- parts) {
                    newPart = [part];
                    if(symb(target, l) := part) {
                        if([] := l) newPart = subParts;
                        else canRemove = false;
                    }
                    newParts += newPart;
                }
                
                affected += def;
                productions[def] -= s;
                productions[def] += concatenateRegexes(
                    convProd(lDef, newParts, {targetSource, convProdSource(s)})
                );
            }
        }

        if(canRemove)  productions = delete(productions, target);

        return <affected, productions>;
    }
    
    return <{}, productions>;
}

set[&T] flatten(set[set[&T]] s) = {*S | S <- s};