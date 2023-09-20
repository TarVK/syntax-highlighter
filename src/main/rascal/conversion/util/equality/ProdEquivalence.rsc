module conversion::util::equality::ProdEquivalence

import conversion::conversionGrammar::ConversionGrammar;
import regex::regexToPSNFA;

@doc {
    Retrieves the symbol that can be used for equivalence checking, removing irrelevant details such as:
    - Exact regex shape (by using the language of the regex, which uniquely defines a minimal normalized DFA)
    - Sources where symbols originated from

    Does not normalize constraints hierarchy
}
ConvSymbol getEquivalenceSymbol(ConvSymbol sym) {
    switch(sym) {
        case ref(r, s, _): return ref(r, s, {});
        case delete(s, d): return delete(getEquivalenceSymbol(s), getEquivalenceSymbol(d));
        case follow(s, f): return follow(getEquivalenceSymbol(s), getEquivalenceSymbol(f));
        case notFollow(s, f): return notFollow(getEquivalenceSymbol(s), getEquivalenceSymbol(f));
        case precede(s, p): return precede(getEquivalenceSymbol(s), getEquivalenceSymbol(p));
        case notPrecede(s, p): return notPrecede(getEquivalenceSymbol(s), getEquivalenceSymbol(p));
        case atEndOfLine(s): return atEndOfLine(getEquivalenceSymbol(s));
        case atStartOfLine(s): return atStartOfLine(getEquivalenceSymbol(s));
        case regexp(r): return regexNfa(regexToPSNFA(r));
        case regexNfa(n): return regexNfa(n);
    }
}
list[ConvSymbol] getEquivalenceSymbols(list[ConvSymbol] symbols) 
    = [getEquivalenceSymbol(s) | s <- symbols];

@doc {
    Checks whether two symbols are equivalent, ignoring irrelevant details such as:
    - Exact regex shape (by using the language of the regex, which uniquely defines a minimal normalized DFA)
    - Sources where symbols originated from

    Does not consider euivalence between different constraints hierarchies
}
bool equals(ConvSymbol a, ConvSymbol b) = getEquivalenceSymbol(a) == getEquivalenceSymbol(b);