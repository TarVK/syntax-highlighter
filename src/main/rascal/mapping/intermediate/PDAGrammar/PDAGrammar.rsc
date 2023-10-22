module mapping::intermediate::PDAGrammar::PDAGrammar

import mapping::intermediate::scopeGrammar::ScopeGrammar;
import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;

data PDAGrammar = PDAGrammar(str \start, PDAProductions productions);
alias PDAProductions = map[str, list[PDAProd]];

data PDAProd(set[SourceProd] sources = {}) 
    = tokenProd(ScopedRegex r)
    | pushProd(ScopedRegex r, str push)
    | popProd(ScopedRegex r)
    | inclusion(str sym);
