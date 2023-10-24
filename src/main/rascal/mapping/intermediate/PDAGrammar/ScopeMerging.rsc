module mapping::intermediate::PDAGrammar::ScopeMerging

import String;
import Set;

import util::List;
import Scope;

@doc { A function that specifies behavior on how scopes should be merged }
alias ScopeMerger = Scope(ScopeList scopes);

@doc { 
    A scope merger that specifies that only the last encountered scope should be kept
}
ScopeMerger useLastScope(Scope defaultScope) =
    Scope (ScopeList scopes) {
        if([*_, last] := scopes) return last;
        return defaultScope;
    };

@doc { 
    A scope merger that specifies that the scopes should be combined, by combining all seperate parts into a single scope string. The parts are also sorted, such that behavior mimics a set 
}
ScopeMerger combineScope(Scope defaultScope) = 
    Scope (ScopeList scopes) {
        if(scopes == []) return defaultScope;

        scopeSet = {*split(".", scope) | scope <- scopes};
        sortedScopes = sort(scopeSet);
        merged = stringify(sortedScopes, ".");
        return merged;
    };