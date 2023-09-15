module conversion::regexConversion::substituteRegexes

import Set;
import Map;
import ParseTree;
import util::Maybe;
import IO;

import Scope;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::liftScopes;
import conversion::regexConversion::concatenateRegexes;
import conversion::regexConversion::lowerModifiers;
import regex::Regex;
import regex::RegexCache;
import regex::RegexProperties;
import regex::PSNFA;
import regex::Tags;

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
    if(
        {convProd(_, subParts)} := targetProds, 
        size(subParts)>0, 
        all(part <- subParts, regexp(_) := part)
    ) {
        set[Symbol] affected = {};
        canRemove = true;

        for(def <- productions) {
            prods = productions[def];
            
            // Note that def and lDef may be different, because of applied labels
            targetProds = {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(target, _, _), *_]) <- prods
            } + {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(label(_, target), _, _), *_]) <- prods
            };
            for(<s,lDef,parts> <- targetProds) {
                list[ConvSymbol] newParts = [];

                ConvSymbol sub(Regex regex, ScopeList scopes, set[SourceProd] sources) {
                    if(sources != {}) regex = meta(regex, sources);
                    if(scopes != []) regex = wrapScopes(regex, scopes);
                    return regexp(regex);
                }
                for(part <- parts) {
                    if([regexp(regex)] := subParts) {
                        newParts += visit(part) {
                            case symb(target, scopes, sources) => sub(regex, scopes, sources)
                            case symb(label(_, target), scopes, sources) => sub(regex, scopes, sources)
                        };
                    }else
                    // When there are multiple parts, we can't substitute them in modifiers since no sequences are allowed in modifiers
                    {
                        newPart = subParts;
                        
                        Maybe[tuple[ScopeList, set[SourceProd]]] scopes = nothing();
                        if(symb(target, l, sources) := part) scopes = just(<l, sources>);
                        else if(symb(label(_, target), l, sources) := part) scopes = just(<l, sources>);
                        // If the part isn't a direct reference to the target (instead a modifier) but does contain it, the symbol can't be removed
                        else visit(part) {
                            case symb(target, _, _): canRemove = false;
                            case symb(label(_, target), _, _): canRemove = false;
                        }
                        
                        if(just(<l, sources>) := scopes) 
                            newPart = [sub(regex, l, sources), regexp(regex) <- subParts];

                        newParts += newPart;
                    }

                }
                
                affected += def;
                productions[def] -= s;
                productions[def] += concatenateRegexes(lowerModifiers(convProd(lDef, newParts)));
            }
        }

        if(canRemove)  productions = delete(productions, target);

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
    Returns the set of affected non-terminals, whether a regex concatenation happened, and the grammar with the substitutions applied.
}
tuple[set[Symbol], bool, ProdMap] substituteSequence(ProdMap productions, Symbol target) {
    if(target notin productions) return <{}, productions>;

    didMergeRegexes = false;
    targetProds = productions[target];
    if({convProd(_, subParts)} := targetProds) {
        containsSelf = any(symb(s, _) <- subParts, getWithoutLabel(s)==target);
        if(containsSelf) break;

        set[Symbol] affected = {};
        canRemove = true;

        for(def <- productions) {
            prods = productions[def];

            // Note that def and lDef may be different, because of applied labels
            targetProds = {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(target, _, _), *_]) <- prods
            } + {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /symb(label(_, target), _, _), *_]) <- prods
            };
            for(<s,lDef,parts> <- targetProds) {
                list[ConvSymbol] newParts = [];
                for(part <- parts) {
                    newPart = [part];

                    Maybe[tuple[ScopeList, set[SourceProd]]] scopes = nothing();
                    if(symb(target, l, sources) := part) scopes = just(<l, sources>);
                    else if(symb(label(_, target), l, sources) := part) scopes = just(<l, sources>);
                    // If the part isn't a direct reference to the target (instead a modifier) but does contain it, the symbol can't be removed
                    else visit(part) {
                        case symb(target, _, _): canRemove = false;
                        case symb(label(_, target), _, _): canRemove = false;
                    }

                    if(just(<l, sources>) := scopes) {
                        if([] := l || subParts == []) 
                            newPart = [
                                visit(part)  {
                                    case regexp(r) => regexp(getCachedRegex(meta(r, sources)))
                                    case symb(s, scopes, sources2) => symb(s, scopes, sources2 + sources)
                                }
                                | part <- subParts];
                        else canRemove = false;
                    }

                    newParts += newPart;
                }
                
                affected += def;
                productions[def] -= s;
                concatenated = concatenateRegexes(convProd(lDef, newParts));
                productions[def] += concatenated;
                if(size(concatenated.parts) < size(newParts)) didMergeRegexes = true;
            }
        }

        if(canRemove)  productions = delete(productions, target);

        return <affected, didMergeRegexes, productions>;
    }
    
    return <{}, false, productions>;
}

@doc {
    Wraps the given regular expresion in the given scope
}
Regex wrapScopes(Regex regex, ScopeList scopeList) {
    Scopes scopes = toScopes(scopeList);
    Regex prefixScopes(Regex regex) {
        if(!containsScopes(regex)) return regex;
        switch(regex) {
            case mark(tags, r): return mark({
                scopeTag(s) := t ? scopeTag(concat(scopes, s)) : t | t <- tags
            }, prefixScopes(r));
            case lookahead(r, la): return lookahead(prefixScopes(r), la);
            case \negative-lookahead(r, la): return \negative-lookahead(prefixScopes(r), la);
            case lookbehind(r, lb): return lookbehind(prefixScopes(r), lb);
            case \negative-lookbehind(r, lb): return \negative-lookbehind(prefixScopes(r), lb);
            case subtract(r, re): return subtract(prefixScopes(r), re);
            case concatenation(h, t): return concatenation(prefixScopes(h), prefixScopes(t));
            case alternation(o1, o2): return alternation(prefixScopes(o1), prefixScopes(o2));
            case \multi-iteration(r): return \multi-iteration(prefixScopes(r));
            case meta(r, m:metaCache(_, _)): return prefixScopes(r);  // Note that we remove the internal caches, since they are no longer correct and we can't use them anymore
            case meta(r, m): return meta(prefixScopes(r), m);
            default: {
                println("Error: missed a case in wrapScopes: <regex>");
                return regex;
            }
        }
    }


    // This only prefixes the regex, not the cached PSNFAs
    prefixedRegexScopes = prefixScopes(regex);

    // Recalculate the cache
    return getCachedRegex(prefixedRegexScopes);
}

