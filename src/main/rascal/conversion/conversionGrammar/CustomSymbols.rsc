module conversion::conversionGrammar::CustomSymbols

import IO;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::util::equality::ProdEquivalence;
import regex::PSNFACombinators;

import testing::util::visualizeGrammars;

data Symbol 
    /* L(convSeq(parts)) = L(parts) */
    = convSeq(list[ConvSymbol] parts)
    /* L(unionRec(options)) = (∪_{s ∈ options} L(s))* */
    | unionRec(set[Symbol] options)
    /* L(closed(A, B)) = (L(sym) . L(close))* */
    | closed(Symbol sym, Symbol close);

@doc {
    Simplifies the given custom symbol, using algebraic simplification rules

    Given input symbol `A`, it returns symbol `B` such that:
    - L(A) = L(B)
}
Symbol simplify(Symbol sym, ConversionGrammar grammar) {
    // Union
    if(unionRec(options) := sym, a<-options, isAlias(a, grammar)) {
        rest = options - {a};
        return simplifyInner(unionRec({followAlias(a, grammar)} + rest), grammar);
    }
    if(unionRec({unionRec(options), *rest}) := sym)
        return simplify(unionRec(options + rest), grammar);

    // Many more simplification rules can be thought of, but the above ones are important ones that actually show up in the algorithm    
    return sym;
}
