module conversionGrammar::regexConversion::substituteRegexes

import Set;
import Map;
import ParseTree;
import util::Maybe;
import IO;

import Scope;
import conversionGrammar::RegexCache;
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
    if({p:convProd(_, [regexp(regex)], _)} := targetProds) {
        targetSource = convProdSource(p);
        set[Symbol] affected = {};

        productions = delete(productions, target);
        for(def <- productions) {
            prods = productions[def];
            
            // Note that def and lDef may be different, because of applied labels
            targetProds = {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(target, _), *_],  _) <- prods
            } + {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(label(_, target), _), *_],  _) <- prods
            };
            for(<s,lDef,parts> <- targetProds) {
                list[ConvSymbol] newParts = [];

                ConvSymbol sub(Scopes scopes) 
                    = regexp(size(scopes)>0 ? wrapScopes(regex, scopes) : regex);
                for(part <- parts)
                    newParts += visit(part) {
                        case symb(target, scopes) => sub(scopes)
                        case symb(label(_, target), scopes) => sub(scopes)
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
    if({p:convProd(_, subParts, _)} := targetProds) {
        targetSource = convProdSource(p);
        set[Symbol] affected = {};
        canRemove = true;

        for(def <- productions) {
            prods = productions[def];

            // Note that def and lDef may be different, because of applied labels
            targetProds = {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(target, _), *_],  _) <- prods
            } + {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(label(_, target), _), *_],  _) <- prods
            };
            for(<s,lDef,parts> <- targetProds) {
                list[ConvSymbol] newParts = [];
                for(part <- parts) {
                    newPart = [part];

                    Maybe[Scopes] scopes = nothing();
                    if(symb(target, l) := part) scopes = just(l);
                    else if(symb(label(_, target), l) := part) scopes = just(l);
                    // If the part isn't a reference to the target but does contain it, the symbol can't be removed
                    else visit(part) {
                        case symb(target, scopes): canRemove = false;
                        case symb(label(_, target), scopes): canRemove = false;
                    }

                    if(just(l) := scopes) {
                        if([] := l || subParts == []) 
                            newPart = subParts;
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

@doc {
    Wraps the given regular expresion in the given scope
}
Regex wrapScopes(Regex regex, Scopes scopes) {
    Regex prefixScopes(Regex regex) {
        switch(regex) {
            case mark(tags, r): return mark({
                scopeTag(s) := t ? scopeTag([*scopes, *s]) : t | t <- tags
            }, prefixScopes(r));
            case lookahead(r, la): return lookahead(prefixScopes(r), la);
            case \negative-lookahead(r, la): return \negative-lookahead(prefixScopes(r), la);
            case lookbehind(r, lb): return lookbehind(prefixScopes(r), lb);
            case \negative-lookbehind(r, lb): return \negative-lookbehind(prefixScopes(r), lb);
            case subtract(r, re): return subtract(prefixScopes(r), re);
            case concatenation(h, t): return concatenation(prefixScopes(h), prefixScopes(t));
            case alternation(o1, o2): return alternation(prefixScopes(o1), prefixScopes(o2));
            case \multi-iteration(r): return \multi-iteration(prefixScopes(r));
            case cached(r, a, s): return cached(prefixScopes(r), a, s);
            default: return regex;
        }
    }

    return liftScopes(mark({scopeTag(scopes)}, prefixScopes(regex)));
}