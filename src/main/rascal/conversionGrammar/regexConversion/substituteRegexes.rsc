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
                for(part <- parts) {
                    newParts += visit(part) {
                        case symb(target, scopes) => sub(scopes)
                        case symb(label(_, target), scopes) => sub(scopes)
                    };
                }
                
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
    Returns the set of affected non-terminals, whether a regex concatenation happened, and the grammar with the substitutions applied.
}
tuple[set[Symbol], bool, ProdMap] substituteSequence(ProdMap productions, Symbol target) {
    if(target notin productions) return <{}, productions>;

    didMergeRegexes = false;
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
                concatenated = concatenateRegexes(
                    convProd(lDef, newParts, {targetSource, convProdSource(s)})
                );
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
            case cached(r, a, s): return prefixScopes(r); // Note that we remove the internal caches, since they are no longer correct and we don't need the anyhow
            default: return regex;
        }
    }


    // This only prefixes the regex, not the cached PSNFAs
    prefixedRegexScopes = prefixScopes(regex);

    // Prefixing the PSNFAs like this is not fully safe, since it assumes all scopes currently in the main transitions to originate from scopes in the main expression (not in prefixes/suffixes).
    // This is not always the case by definition, but is the case in rascal since prefix/suffixes are more limited
    // And moreover, TM doesn't support scopes in prefixes/suffixes. Hence it's safe for us to make this assumption
    regexNFA = regexToPSNFA(regex);
    <prefixStates, mainStates, suffixStates> = getPSNFApartition(regexNFA);
    mainCharTransitions = {t | t:<from, character(_, _), to> <- regexNFA.transitions, from in mainStates};

    TagsClass modifyTags(TagsClass tc) = regex::Tags::merge(
            visit (tc) {
                case scopeTag(s) => scopeTag([*scopes, *s])
            },
            {{scopeTag(scopes)}}
        );

    scopedNFA = <
        regexNFA.initial,
        {
            <from, character(cc, modifyTags(tc)), to> | <from, character(cc, tc), to> <- mainCharTransitions
        } + {
            trans | trans <- regexNFA.transitions - mainCharTransitions
        },
        regexNFA.accepting,
        ()
    >;

    return cached(mark({scopeTag(scopes)}, prefixedRegexScopes), scopedNFA, true);
}

