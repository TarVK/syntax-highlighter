module conversion::shapeConversion::deduplicateClosings

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::equality::getEquivalentSymbols;
import conversion::util::equality::deduplicateSymbols;

@doc {
    Deduplicates symbols in the grammar, considering that `closed` symbols with an equivalent inner symbol must be equivalent themselves
}
ConversionGrammar deduplicateClosings(ConversionGrammar grammar, set[Symbol] newlyDefined) {
    ConversionGrammar oldGrammar = grammar;
    return deduplicateSymbols(
        grammar,
        Symbol(Symbol a, Symbol b) {
            if(grammar.\start == a) return a;
            if(grammar.\start == b) return b;

            // Deprioritize newly defined symbols
            if(a in newlyDefined) return b;
            if(b in newlyDefined) return a;

            // Prioritize smaller unions
            if(unionRec(A) := a || unionRec(B) := b) {
                if(A < B) return A;
                if(B < A) return B;
            }

            // Deprioritize unions
            if(unionRec(_) := a) return b;
            if(unionRec(_) := b) return a;

            return a;
        },
        DedupeType(Symbol) {
            return reference();
        },
        bool(Symbol a, Symbol b, ClassMap classes) {
            if(closed(ac, c) := a, closed(bc, c) := b){
                a = ac;
                b = bc;
            }

            return defaultSymEquals(a, b, classes);
        }
    );
}