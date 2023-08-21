module conversion::shapeConversion::unionSym

import ParseTree;
import Set;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;
import regex::Regex;
import Visualize;

@doc {
    A symbol that captures all relevant data of a derived union of multiple symbols.
    This flattens out any nested union symbols in order to remove irrelevant structural information.
    A custom symbol is used for better visualizations in Rascal-vis, but the regular expressions can only be stored as annotations.

    Note that the sources of expressions are only used when the symbol is not yet defined in the grammar. As soon as the unionSym gets defined in the grammar, both the definition and all references to it should use empty sets of sources for regexes to prevent duplication.
}
Symbol unionSym(set[Symbol] parts, set[tuple[Regex, set[SourceProd]]] expressions) {
    // Flatten out any nested unionWSyms
    while({custom("union", annotate(\alt(iParts), annotations)), *rest} := parts) {
        for(regexProd(exp, sources) <- annotations)
            expressions += <exp, sources>;
        parts = rest + iParts;
    }

    // Create the new symbol
    return custom("union", annotate(\alt(parts), {regexProd(removeInnerRegexCache(r), sources) | <r, sources> <- expressions}));
}
data RegexProd = regexProd(Regex, set[SourceProd]);

@doc {
    Removes the expression sources from the given symbol, to prevent irrelevant information from creating duplicate symbols in the grammar
}
Symbol removeRegexSources(custom("union", annotate(\alt(parts), annotations))) {
    set[tuple[Regex, set[SourceProd]]] expressions = {};
    for(regexProd(r, _) <- annotations)
        expressions += <r, {}>;

    return unionSym(parts, expressions);
}