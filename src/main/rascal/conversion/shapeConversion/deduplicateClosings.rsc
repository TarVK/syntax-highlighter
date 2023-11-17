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

            // Prioritize bigger unions (more trivial merging)
            if(unionRec(A) := a && unionRec(B) := b) {
                if(A > B) return a;
                if(B > A) return b;
            }

            // // Prioritize unionRecs in general
            // if(unionRec(_) := a) return a;
            // if(unionRec(_) := b) return b;

            // Deprioritize unionRecs in general, 
            // prevents unionRec({a, b, c}) simplification contradictions when `a -> unionRec({a, b})`
            if(unionRec(_) := a) return b;
            if(unionRec(_) := b) return a;

            // Deprioritize newly defined symbols
            if(a in newlyDefined, b notin newlyDefined) return b;
            if(b in newlyDefined, a notin newlyDefined) return a;

            return a;
        },
        DedupeType(Symbol) {
            return reference();
        },
        bool(Symbol a, Symbol b, ClassMap classes) {
            if(closed(ac, c) := a, closed(bc, c) := b){
                if(defaultSymEquals(a, b, classes)) return true;
                a = ac;
                b = bc;
            }

            return defaultSymEquals(a, b, classes);
        }
    );
}