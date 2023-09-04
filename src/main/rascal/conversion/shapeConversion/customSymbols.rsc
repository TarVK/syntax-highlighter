module conversion::shapeConversion::customSymbols

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
            /*
                This symbol has a specification, and implementation. 
                The specification declares intent, which defines a lowerbound on the language included by this symbol.
                The implementation declares outcome, which defines an upperbound on the language included by this symbol.

                Specification:  L(unionRec(A|B, C|D)) = {ps | p ∈ (L(A) ∪ L(B))*, s ∈ {L(C) ∪ L(D)}
                Implementation: L(unionRec(A|B, C|D)) = {ps | p ∈ (L(A) ∪ L(B))*, s ∈ {$e} ∪ L(C) ∪ L(D)}
            */
            | unionRec(set[Symbol] recOptions, set[Symbol] endOptions);

@doc {
    We apply normalization rules `A -> B` that maintain the lowerbound of the specification, 
    ensuring that `L(A) ⊆ L(B)`:

    - unionRec(, A) -> A // We're assuming A is already nullable
    - unionRec(convSeq()|A, B) -> unionRec(A, B)
    - unionRec(A|unionRec(B, C), D) -> unionRec(A|B|C, D)
    - unionRec(A, unionRec(B, C)|D) -> unionRec(A|B, C|D)
    - unionRec(A, A|B) -> unionRec(A, B)
}
Symbol unionRec({}, {end}) = end;
Symbol unionRec({convSeq([]), *recOptions}, endOptions) 
    = unionRec(recOptions, endOptions);
Symbol unionRec({unionRec(ro, eo), *recOptions}, endOptions) 
    = unionRec({*ro, *eo, *recOptions}, endOptions);
Symbol unionRec(recOptions, {unionRec(ro, eo), *endOptions}) 
    = unionRec({*ro, *recOptions}, {*eo, *endOptions});
Symbol unionRec({op, *recOptions}, {op, *endOptions}) 
    = unionRec({op, *recOptions}, endOptions);


/*
    Correctness of normalization (applied to implementation, should be redone for specification):

    # unionRec(, A) -> A
    ```
    a ∈ L(unionRec(, A))
    => {Definition}
    a ∈ {ps | p ∈ ({})*, s ∈ {$e} ∪ L(A)}
    => {Kleen star empty domain}
    a ∈ {ps | p = $e, s ∈ {$e} ∪ L(A)}
    => {Empty string concatenation}
    a ∈ {s | s ∈ {$e} ∪ L(A)}
    => {Set inclusion}
    a ∈ {$e} ∪ L(A)
    => {$e is part of L(A) if A is nullable}
    a ∈ L(A)
    ```

    # unionRec(A|unionRec(B, C), D) -> unionRec(A|B|C, D)
    ```
    a ∈ L(unionRec(A|unionRec(B, C), D))
    => {Definition}
    a ∈ {ps | p ∈ (L(A) ∪ L(unionRec(B, C)))*, s ∈ {$e} ∪ L(D)}
    => {Definition}
    a ∈ {ps | p ∈ (L(A) ∪ {ps | p ∈ L(B)*, s ∈ {$e} ∪ L(C))})*, s ∈ {$e} ∪ L(D)}
    => {Generalization}
    a ∈ {ps | p ∈ (L(A) ∪ L(B) ∪ L(C))*, s ∈ {$e} ∪ L(D)}
    => {Definition}
    a ∈ L(unionRec(A|B|C, D))
    ```

    Proving this generalization is not so easy, and requires some inductive proof for:
    `(L(A) ∪ L({ps | p ∈ L(B)*, s ∈ {$e} ∪ L(C))}))* ⊆ (L(A) ∪ L(B) ∪ L(C))*`

    We can make a decently simple argument however:
    Assume a string `a` is part of the former, but not the latter. Then the string must not be constructable by putting elements of  L(A), L(B), or L(C) in a sequence, since `(L(A) ∪ L(B) ∪ L(C))*` can cmbine elements of these languages in every possible sequence. But `(L(A) ∪ L({ps | p ∈ L(B)*, s ∈ {$e} ∪ L(C))}))*` only takes elements of L(A), L(B), and L(C) and puts them in a sequence, so we reach a contradiction.


    # unionRec(A, unionRec(B, C)|D) -> unionRec(A|B, C|D)
    ```
    a ∈ L(unionRec(A, unionRec(B, C)|D))
    => {Definition}
    a ∈ {ps | p ∈ L(A)*, s ∈ {$e} ∪ L(unionRec(B, C)) ∪ L(D)}
    => {Definition}
    a ∈ {ps | p ∈ L(A)*, s ∈ {$e} ∪ {ps | p ∈ L(B)*, s ∈ {$e} ∪ L(C)} ∪ L(D)}
    => {Union inclusion}
    a ∈ {ps | p ∈ L(A)*, s ∈ {$e} ∪ L(D) ∨ s ∈ {ps | p ∈ L(B)*, s ∈ {$e} ∪ L(C)}}
    => {Union inclusion}
    a ∈ {ps | p ∈ L(A)*, s ∈ {$e} ∪ L(D)} 
      ∪ {ps | p ∈ L(A)*, s ∈ {ps | p ∈ L(B)*, s ∈ {$e} ∪ L(C)}}
    => {Generalization (see sub-calculation)}
    a ∈ {ps | p ∈ (L(A) ∪ L(B))*, s ∈ {$e} ∪ L(C) ∪ L(D)} 
      ∪ {ps | p ∈ (L(A) ∪ L(B))*, s ∈ {$e} ∪ L(C) ∪ L(D)} 
    => {Set inclusion}
    a ∈ {ps | p ∈ (L(A) ∪ L(B))*, s ∈ {$e} ∪ L(C) ∪ L(D)} 
    => {Definition}
    a ∈ unionRec(A|B, C|D)
    ```

    The first generalization is trivial:
    ```
    a ∈ {ps | p ∈ L(A)*, s ∈ {$e} ∪ L(D)} 
    => {Union widening}
    a ∈ {ps | p ∈ (L(A) ∪ L(B))*, s ∈ {$e} ∪ L(C) ∪ L(D)}
    ```

    The second inclusion is trickier and harder to properly prove
    ```
    a ∈ {ps | p ∈ L(A)*, s ∈ {ps | p ∈ L(B)*, s ∈ {$e} ∪ L(C)}}
    <=> {Renaming}
    a ∈ {ps | p ∈ L(A)*, s ∈ {p's' | p' ∈ L(B)*, s' ∈ {$e} ∪ L(C)}}
    <=> {Substitution}
    a ∈ {pp's' | p ∈ L(A)*, p' ∈ L(B)*, s' ∈ {$e} ∪ L(C)}
    <=> {Substitution}
    a ∈ {ws' | w ∈ {pp' | p ∈ L(A)*, p' ∈ L(B)*}, s' ∈ {$e} ∪ L(C)}
    => {Generalization (Allow elements of A and B to be mixed in order)}
    a ∈ {ws' | w ∈ (L(A) ∪ L(B))*, s' ∈ {$e} ∪ L(C)}
    => {Union widening}
    a ∈ {ws' | w ∈ (L(A) ∪ L(B))*, s' ∈ {$e} ∪ L(C) ∪ L(D)}
    => {Renaming}
    a ∈ {ps | p ∈ (L(A) ∪ L(B))*, s ∈ {$e} ∪ L(C) ∪ L(D)}
    ```
*/