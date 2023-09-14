module conversion::conversionGrammar::customSymbols

import ParseTree;
import Set;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;
import regex::Regex;
import Visualize;

data Symbol = 
            // L(convSeq(A B)) = L(A B)
            convSeq(list[ConvSymbol] parts) 
            // L(unionRec(A|B) = (L(A) ∪ L(B))*
            | unionRec(set[Symbol] recOptions)
            // L(clsoedBy(A, X)) = L(A)  (only difference is that we know `X` must follow in this context, and we ensure a produciton of A can happen when this occurs)
            | closedBy(Symbol target, Regex closer);

@doc {
    We apply normalization rules `A -> B` such that `L(A) = L(B)`:

    - unionRec(A) -> A // We're assuming A is already nullable/right recursive
    - unionRec(convSeq()|A) -> unionRec(A)
    - unionRec(A|unionRec(B)) -> unionRec(A|B)
}
Symbol unionRec({single}) = single;
Symbol unionRec({convSeq([]), *options}) 
    = unionRec(options);
Symbol unionRec({unionRec(ro), *options}) 
    = unionRec({*ro, *options});