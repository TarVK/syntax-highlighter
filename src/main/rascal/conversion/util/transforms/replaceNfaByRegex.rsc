module conversion::util::transforms::replaceNfaByRegex

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::Alias;

@doc {
    Tries to use convSeq's definitions to relabel their symbols to their definition
}
ConversionGrammar replaceNfaByRegex(ConversionGrammar grammar) {
    prods = grammar.productions;
    return visit(grammar) {
        case cs:convSeq(parts): {
            // Follow aliases
            while({convProd(_, orParts)} := prods[cs], [ref(sym, [], {})] := orParts) {
                cs = sym;
            }

            // Replace all regexNfas by regexes when possible
            if({convProd(_, orParts)} := prods[cs], size(parts)==size(orParts)) {
                for(i <- [0..size(orParts)]) {
                    if(regexNfa(_) := parts[i], regexp(_) := orParts[i]) 
                        parts[i] = orParts[i];
                }
            }

            insert convSeq(parts);
        }
    };
}
