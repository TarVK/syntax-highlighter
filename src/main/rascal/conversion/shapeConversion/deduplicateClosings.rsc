module conversion::shapeConversion::deduplicateClosings

import Relation;
import Map;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::equality::getEquivalentSymbols;
import conversion::util::equality::deduplicateSymbols;
import conversion::util::BaseNFA;
import regex::PSNFA;
import regex::regexToPSNFA;
import regex::RegexTypes;

@doc {
    Deduplicates symbols in the grammar, considering that `closed` symbols with an equivalent inner symbol must be equivalent themselves
}
ConversionGrammar deduplicateClosings(ConversionGrammar grammar, set[Symbol] newlyDefined) {
    ConversionGrammar oldGrammar = grammar;
    <grammar, deduped> = deduplicateSymbolsWithDeduped(
        grammar,
        Symbol(Symbol a, Symbol b) {
            if(grammar.\start == a) return a;
            if(grammar.\start == b) return b;

            // Prioritize bigger unions (more trivial merging) for base NFAs
            if(unionRec(A, emptyNFA) := a, unionRec(B, emptyNFA) := b) {
                if(A > B) return a;
                if(B > A) return b;
            }

            // Prioritize base nfas to be kept
            if(unionRec(_, emptyNFA) := a) return a;
            if(unionRec(_, emptyNFA) := b) return b;

            // Prioritize bigger unions (more trivial merging)
            if(unionRec(A, _) := a, unionRec(B, _) := b) {
                if(A > B) return a;
                if(B > A) return b;
            }

            // Prioritize unionRecs in general
            if(unionRec(_, _) := a) return a;
            if(unionRec(_, _) := b) return b;
            
            // Deprioritize newly defined symbols
            if(a in newlyDefined, b notin newlyDefined) return b;
            if(b in newlyDefined, a notin newlyDefined) return a;

            return a;
        },
        DedupeType(Symbol) {
            return reference();
        },
        bool(Symbol a, Symbol b, ClassMap classes) {
            if(closed(ac, c) := a, closed(bc, c) := b) {
                if(defaultSymEquals(a, b, classes)) return true;
                a = ac;
                b = bc;
            }

            if(unionRec(syms1, c) := a, unionRec(syms2, c) := b) {
                if(defaultSymEquals(a, b, classes)) return true;
                a = unionRec(syms1, emptyNFA);
                b = unionRec(syms2, emptyNFA);
            }

            return defaultSymEquals(a, b, classes);
        }
    );

    return grammar;
}

