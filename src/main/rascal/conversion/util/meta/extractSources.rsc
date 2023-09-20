module conversion::util::meta::extractSources

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::RegexSources;
import regex::RegexTypes;

@doc {
    Extract all sources from the given symbols
}
set[SourceProd] extractSources(list[ConvSymbol] syms) 
    = {*extractSources(s) | s <- syms};

@doc {
    Extract all sources from the given symbol
}
set[SourceProd] extractSources(ConvSymbol sym) {
    switch(sym) {
        case ref(_, _, sources): return sources;
        case regexp(r): return extractAllRegexSources(r);
    }
    return {};
}
