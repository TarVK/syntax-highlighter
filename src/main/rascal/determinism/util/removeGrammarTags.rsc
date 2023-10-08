module determinism::util::removeGrammarTags

import conversion::conversionGrammar::ConversionGrammar;
import regex::RegexCache;
import regex::RegexStripping;

@doc {
    Removes all tags from productions of a grammar
}
ConversionGrammar removeGrammarTags(ConversionGrammar grammar) {
    rel[Symbol, ConvProd] outProds = {};

    for(<sym, p> <- grammar.productions)
        outProds += <sym, removeProductionTags(p)>;

    return convGrammar(grammar.\start, outProds);
}

@doc {
    Removes all tags from the given production
}
ConvProd removeProductionTags(convProd(lDef, parts)) {
    list[ConvSymbol] newParts = [];
    ConvSymbol removeTag(ConvSymbol s) {
        switch(s) {
            case regexp(p): return regexp(removeTags(p));
            case ref(refSym, _, sources): return ref(refSym, [], sources);
            case delete(from, del): return delete(removeTags(from), rmoveTags(del));
            case follow(sym, f): return follow(removeTags(sym), rmoveTags(f));
            case notFollow(sym, f): return notFollow(removeTags(sym), rmoveTags(f));
            case precede(sym, p): return follow(removeTags(sym), rmoveTags(p));
            case notPrecede(sym, p): return notPrecede(removeTags(sym), rmoveTags(p));
            case atStartOfLine(sym): return atStartOfLine(removeTags(sym));
            case atEndOfLine(sym): return atEndOfLine(removeTags(sym));
        }
    }

    for(part <- parts)
        newParts += removeTag(part);
        
    return convProd(lDef, newParts);
}