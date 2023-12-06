module conversion::regexConversion::substituteRegexes

import Set;
import Map;
import ParseTree;
import util::Maybe;
import IO;

import Scope;
import conversion::util::meta::LabelTools;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::liftScopes;
import conversion::regexConversion::concatenateRegexes;
import conversion::regexConversion::lowerModifiers;
import conversion::util::meta::applyScopesAndSources;
import conversion::util::meta::wrapRegexScopes;
import regex::Regex;
import regex::RegexCache;
import regex::RegexProperties;
import regex::PSNFA;

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
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /ref(target, _, _), *_]) <- prods
            } + {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /ref(label(_, target), _, _), *_]) <- prods
            };
            for(<s,lDef,parts> <- targetProds) {
                list[ConvSymbol] newParts = [];

                ConvSymbol sub(Regex regex, ScopeList scopes, set[SourceProd] sources) {
                    if(sources != {}) regex = meta(regex, sources);
                    if(scopes != []) regex = wrapRegexScopes(regex, scopes);
                    return regexp(regex);
                }
                for(part <- parts) {
                    if([regexp(regex)] := subParts) {
                        newParts += visit(part) {
                            case ref(target, scopes, sources) => sub(regex, scopes, sources)
                            case ref(label(_, target), scopes, sources) => sub(regex, scopes, sources)
                        };
                    }else
                    // When there are multiple parts, we can't substitute them in modifiers since no sequences are allowed in modifiers
                    {
                        newPart = subParts;
                        
                        Maybe[tuple[ScopeList, set[SourceProd]]] scopes = nothing();
                        if(ref(target, l, sources) := part) scopes = just(<l, sources>);
                        else if(ref(label(_, target), l, sources) := part) scopes = just(<l, sources>);
                        // If the part isn't a direct reference to the target (instead a modifier) but does contain it, the symbol can't be removed
                        else visit(part) {
                            case ref(target, _, _): canRemove = false;
                            case ref(label(_, target), _, _): canRemove = false;
                        }
                        
                        if(just(<l, sources>) := scopes) 
                            newPart = [sub(regex, l, sources) | regexp(regex) <- subParts];

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
        containsSelf = any(ref(s, _, _) <- subParts, getWithoutLabel(s)==target);
        if(containsSelf) break;

        set[Symbol] affected = {};
        canRemove = true;

        for(def <- productions) {
            prods = productions[def];

            // Note that def and lDef may be different, because of applied labels
            occuredInProds = {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /ref(target, _, _), *_]) <- prods
            } + {
                <s, lDef, parts> | s:convProd(lDef, parts:[*_, /ref(label(_, target), _, _), *_]) <- prods
            };
            for(<s,lDef,parts> <- occuredInProds) {
                list[ConvSymbol] newParts = [];
                for(part <- parts) {
                    newPart = [part];

                    Maybe[tuple[ScopeList, set[SourceProd]]] scopes = nothing();
                    if(ref(target, l, sources) := part) scopes = just(<l, sources>);
                    else if(ref(label(_, target), l, sources) := part) scopes = just(<l, sources>);
                    // If the part isn't a direct reference to the target (instead a modifier) but does contain it, the symbol can't be removed
                    else visit(part) {
                        case ref(target, _, _): canRemove = false;
                        case ref(label(_, target), _, _): canRemove = false;
                    }

                    if(just(<l, sources>) := scopes) 
                        newPart = [applyScopesAndSources(p, l, sources) | p <- subParts];

                    newParts += newPart;
                }
                
                affected += def;
                productions[def] -= s;
                concatenated = concatenateRegexes(convProd(lDef, newParts));
                productions[def] += concatenated;
                if(size(concatenated.parts) < size(newParts)) didMergeRegexes = true;
            }
        }

        if(canRemove) productions = delete(productions, target);

        return <affected, didMergeRegexes, productions>;
    }
    
    return <{}, false, productions>;
}