module conversion::conversionGrammar::CustomSymbols

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::util::equality::ProdEquivalence;
import conversion::util::BaseNFA;
import regex::PSNFACombinators;
import regex::PSNFASimplification;
import regex::RegexTypes;
import regex::regexToPSNFA;
import regex::NFA;

data Symbol 
    /* L(convSeq(parts)) = L(parts) */
    = convSeq(list[ConvSymbol] parts)
    /* 
    L(unionRec(options)) = (∪_{s ∈ options} L(s))*;
    L(unionRec(options)) ⊆ L(unionRec(options, closing)) 

    such that:
    - ∀ (p, (w, t), s) ∈ L(unionRec(options)) 
        . ∀ t2 ∈ T* ∧ t != t2 
            . (p, (w, t2), s) ∈ L(unionRec(options, closing))
            => (p, (w, t2), s) ∈ L(unionRec(options))
      I.e. if a word exists in the language, if any other combination with tags exists, it's part of L(unionRec(options))
    - ∀ (p, (w, t), s) ∈ L(unionRec(options, closing))
        . ∀ (w2, t2) ∈ (Σ ⨯ T*)*
            . (p, (w w2, t t2), s) ∈ L(unionRec(options, closing))
                => (
                    ! overlap({w2}, L(closing))
                    ∨ (p, (w w2, t t2), s) ∈ L(unionRec(options))
                )
        where 
            overlap(L1, L2) = ∃ w1, w2 ∈ Σ* . (w1w2 ∈ L1 ∧ w1 ∈ L2) or (w1 ∈ L1 ∧ w1w2 ∈ L2)

        I.e. if a word in the language can be extended, then either that extension is part of L(unionRec(options)), or it does not overlap with the closing NFA

    Overall, L(unionRec(options, closing)) is the same as L(unionRec(options)), except that some more combinations are added as long as they don't interfere with the closing expressions or other sentences in the language
    */
    | unionRec(set[Symbol] options, NFA[State] closing)
    /* L(closed(A, B)) = (L(sym) . L(close))* */
    | closed(Symbol sym, Symbol close);

Symbol unionRec(set[Symbol] options) = unionRec(options, neverNFA);

@doc {
    Simplifies the given custom symbol, using algebraic simplification rules

    Given input symbol `A`, it returns symbol `B` such that:
    - L(A) = L(B)
}
Symbol simplify(Symbol sym, ConversionGrammar grammar) {
    // Union
    // if(
    //     unionRec(syms, closing) := sym, 
    //     isAlias(unionRec(syms, emptyNFA), grammar),
    //     unionRec(newSyms, _) := followAlias(unionRec(syms, emptyNFA), grammar)
    // ) 
    //     return simplify(unionRec(newSyms, closing), grammar);
    if(unionRec({unionRec(options, closing1), *rest}, closing2) := sym)
        return simplify(unionRec(options + rest, unionNFA(closing1, closing2)), grammar);
    if(unionRec({a, *rest}, closing) := sym, isAlias(a, grammar))
        return simplify(unionRec({followAlias(a, grammar)} + rest, closing), grammar);

    // Many more simplification rules can be thought of, but the above ones are important ones that actually show up in the algorithm    
    return sym;
}

@doc {
    unions two NFAs
}
NFA[State] unionNFA(NFA[State] a, NFA[State] b){
    if(isEmpty(a)) return b;
    if(isEmpty(b)) return a;
    return minimizeUnique(unionPSNFA(a, b));
}