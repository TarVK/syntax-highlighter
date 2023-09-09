module mapping::intermediate::scopeGrammar::ScopeGrammar

import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;
import Scope;

data ScopeGrammar = scopeGrammar(Symbol \start, ScopeProductions productions);
alias ScopeProductions = map[Symbol, set[ScopeProd]];

data ScopeProd(set[SourceProd] sources = {}) 
    = tokenProd(ScopedRegex r)
    | scopeProd(
        ScopedRegex open,
        ScopedSymbol newProds,
        ScopedRegex close
    )
    | inclusion(Symbol sym);

alias ScopedRegex = tuple[Regex pattern, list[Scope] scopes];
alias ScopedSymbol = tuple[Symbol, Scope];