module mapping::intermediate::scopeGrammar::ScopeGrammar

import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;
import Scope;

data ScopeGrammar = scopeGrammar(str \start, ScopeProductions productions);
alias ScopeProductions = map[str, list[ScopeProd]];

data ScopeProd(set[SourceProd] sources = {}) 
    = tokenProd(ScopedRegex r)
    | scopeProd(
        ScopedRegex open,
        ScopedSymbol newProds,
        ScopedRegex close
    )
    | inclusion(str sym);

alias ScopedRegex = tuple[Regex pattern, list[Scope] scopes];
alias ScopedSymbol = tuple[str, Scope];