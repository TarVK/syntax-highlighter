module mapping::intermediate::PDAGrammar::mergeScopes

import List;

import mapping::intermediate::PDAGrammar::ScopeMerging;
import mapping::intermediate::PDAGrammar::mergeRegexTags;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::intermediate::scopeGrammar::extractRegexScopes;
import regex::RegexTypes;
import regex::Tags;
import Scope;
import Warning;

@doc {
    Merges the scopes in a scope grammar according to a given merge function, such that exaclty one scope applies to every character of a phrase in the language. 
}
WithWarnings[ScopeGrammar] mergeScopes(ScopeGrammar grammar, ScopeMerger merge) {
    Scope defaultScope = merge([]);

    // Helper functions to queue symbol + scope combinations, and creaate unique names for each
    set[str] takenNames = {};
    map[tuple[str, Scope], str] scopedSymbolnames = ();
    set[tuple[str, Scope]] queue = {};
    str getScopedNameAndQueue(str sym, Scope scope) {
        if(<sym, scope> in scopedSymbolnames) return scopedSymbolnames[<sym, scope>];

        id = 0;
        name = "<sym>-<scope>";
        if(name in takenNames) {
            while("<name>$<id>" in takenNames) id++;
            name = "<name>$<id>";
        }

        scopedSymbolnames[<sym, scope>] = name;
        takenNames += name;
        queue += <sym, scope>;
        return name;
    }

    // Helper function to merge the scopes within a regular expression, and generate appriopriate warnings
    list[Warning] warnings = [];
    ScopedRegex mergeScopes(<regex, scopes>, ScopeMerger merge, Scope parentScope, ScopeProd prod) {
        regexWithMergedScopes = mergeRegexTags(regex, Tags(list[Tags] tagsList) {
            scopesInTagList = [
                scopes[i] 
                | tags <- tagsList, 
                captureGroup(i) <- tags, 
                0 <= i && i < size(scopes)
            ];
            if(parentScope != defaultScope) scopesInTagList = [parentScope] + scopesInTagList;
            if(size(scopesInTagList) > 1) warnings += disallowedNestedScopes(scopesInTagList, prod);
            newScope = merge(scopesInTagList);
            return {scopeTag(toScopes([newScope]))};
        });
        return extractRegexScopes(regexWithMergedScopes);
    }

    // The main conversion loop
    ScopeProductions outProds = ();
    newStartSym = getScopedNameAndQueue(grammar.\start, defaultScope);
    while({<sym, scope>, *rest} := queue) {
        queue = rest;

        list[ScopeProd] symProds = [];
        for(prod <- grammar.productions[sym]) {
            if(tokenProd(r) := prod)
                symProds += tokenProd(mergeScopes(r, merge, scope, prod), sources=prod.sources);
            else if(scopeProd(open, <newSym, newScope>, close) := prod) {
                if(newScope == "") newScope = scope;
                else if(scope != defaultScope) {
                    nesting = [scope, newScope];
                    warnings += disallowedNestedScopes(nesting, prod);
                    newScope = merge(nesting);
                }
                symProds += scopeProd(
                    mergeScopes(open, merge, scope, prod), 
                    <getScopedNameAndQueue(newSym, newScope), "">,
                    mergeScopes(close, merge, scope, prod),
                    sources=prod.sources
                );
            }
            else if(inclusion(s) := prod)
                symProds += inclusion(getScopedNameAndQueue(s, scope));
        }

        outProds[getScopedNameAndQueue(sym, scope)] = symProds;
    }

    return <warnings, scopeGrammar(newStartSym, outProds)>;
}