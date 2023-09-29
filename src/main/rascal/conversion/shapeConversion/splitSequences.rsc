module conversion::shapeConversion::splitSequences

import Relation;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::shapeConversion::defineSequence;
import conversion::util::equality::ProdEquivalence;
import conversion::util::equality::deduplicateProds;
import conversion::util::meta::LabelTools;
import conversion::util::makeLookahead;
import conversion::util::Alias;
import regex::PSNFA;
import regex::PSNFATools;
import regex::regexToPSNFA;
import Warning;

data SequenceSplitting 
    /* Never split sequences prematurely */
    = neverSplit() 
    /* Split only if it doesn't broaden symbols */
    | splitIfEqual() 
    /* Always split expressions that cause no overlap */
    | alwaysSplit();

@doc {
    Splits a given sequence if safe
    ```
    unionRec(S, Z) -> X A Y unionRec(S, Z)
    ```
    => if !overlap(Y, Z) ∧ unionRec(S, Z) == unionRec(S|A, Z)
    ```
    unionRec(S, Z) -> X unionRec(S, Z)
    unionRec(S, Z) -> Y unionRec(S, Z)
    ```
}
tuple[
    list[Warning] warnings,
    set[ConvProd] prods,
    ConversionGrammar grammar
] splitSequences(set[ConvProd] prods, NFA[State] close, ConversionGrammar grammar, SequenceSplitting splitting) {
    if(splitting == neverSplit()) return <[], prods, grammar>;

    list[Warning] warnings = [];

    set[tuple[NFA[State], list[ConvSymbol]]] checkSequences = {
        <regexToPSNFA(r), getEquivalenceSymbols(parts)> | convProd(_, parts:[regexp(r), *_]) <- prods
    } + <close, []>;

    set[ConvProd] out = {p | p:convProd(_, []) <- prods};
    set[ConvProd] queue = prods;
    while({prod:convProd(lDef, parts:[regexp(r), *_]), *rest} := queue) {
        queue = rest;
        checkSequences -= <regexToPSNFA(r), getEquivalenceSymbols(parts)>;

        /*
            Remove any unnecessary lookaheads if we try to broaden right away, 
            E.g. 
            ```
            unionRec(Exp|convSeq(s1)) -> X unionRec(Exp) />Y/ unionRec(Exp|convSeq(s1))
            ```
            =>
            ```
            unionRec(Exp|convSeq(s1)) -> X unionRec(Exp|convSeq(s1))
            ```
        */
        if(
            [*p, ref(sym, [], symSources), rp:regexp(r2), rr:ref(rec, [], recSources)] := parts,
            symbolsCanMerge(sym, rec, grammar),
            acceptsEmpty(r2)
        ) {
            prefixParts = [*p, ref(rec, [], symSources)];
            checkSequences += <regexToPSNFA(r), getEquivalenceSymbols(prefixParts)>;
            queue += convProd(lDef, prefixParts);

        /*
            Split the sequence if this does not cause extra non-determinism,
            E.g.
            ```
            unionRec(Exp|convSeq(s1), Z) -> X unionRec(Exp, Z) Y unionRec(Exp|convSeq(s1), Z)
            ```
            => if ∀ W in firstRegexOfAlts ∪ {Z} . !overlap(Y, W)
            ```
            unionRec(Exp|convSeq(s1), Z) -> X unionRec(Exp|convSeq(s1), Z)
            unionRec(Exp|convSeq(s1), Z) -> Y unionRec(Exp|convSeq(s1), Z)
            ```            
        */
        } else if(
            [*p, ref(sym, [], symSources), rp:regexp(_), *s, rr:ref(rec, [], recSources)] := parts,
            symbolsCanMerge(sym, rec, grammar),
            !overlaps(checkSequences, [*p, rr], [rp, *s, rr])
        ) {
            secondHalf = [rp, *s, rr];
            queue += convProd(lDef, secondHalf);
            checkSequences += <regexToPSNFA(secondHalf[0].regex), getEquivalenceSymbols(secondHalf)>;

            // For the first half, we have to indicate we can now also perform the second half, since this data could be lost when merging unions otherwise
            <uWarnings, secondHalfSeq, grammar> = defineSequence([rp, *s], prod, grammar);
            warnings += uWarnings;

            augmentedRecSym = simplify(unionRec({rec, secondHalfSeq}), grammar);
            firstHalf = [*p, ref(augmentedRecSym, [], symSources)];
            queue += convProd(lDef, firstHalf);
            checkSequences += <regexToPSNFA(firstHalf[0].regex), getEquivalenceSymbols(firstHalf)>;

            grammar.productions += {<augmentedRecSym, convProd(augmentedRecSym, [ref(getWithoutLabel(lDef), [], {})])>};
        // If no transformations apply, just add the production to the output
        } else {
            checkSequences += <regexToPSNFA(r), getEquivalenceSymbols(parts)>;
            out += convProd(lDef, parts);
        }
    }

    return <warnings, deduplicateProds(out), grammar>;
}

@doc {
    Check whether the given symbol could be broadened to the specified symbol
}
bool symbolsCanMerge(Symbol sym, Symbol broaden, ConversionGrammar grammar) {
    if(unionRec(broadenSyms, c1) := broaden) {
        if(unionRec(syms, c2) := sym) {
            return simplify(unionRec({s | s <- broadenSyms, convSeq(_) !:= s}), grammar) 
                == simplify(unionRec({s | s <- syms, convSeq(_) !:= s}), grammar);
        } else {
            return followAlias(sym, grammar) == broaden;
        }
    }
    return false;
}

@doc {
    Checks whether any of the given alternations overlaps with the given split expression
}
bool overlaps(
    set[tuple[NFA[State], list[ConvSymbol]]] alternations, 
    list[ConvSymbol] split1, 
    list[ConvSymbol] split2
) {
    if([regexp(r1), *_] := split1, [regexp(r2), *_] := split2) {
        split1CompareSequence = getEquivalenceSymbols(split1);
        split2CompareSequence = getEquivalenceSymbols(split2);

        nfa2 = regexToPSNFA(r2);
        checks = alternations + <regexToPSNFA(r1), split1CompareSequence>;
        return any(<checkNfa, checkSeq> <- checks, overlaps(checkNfa, nfa2), checkSeq != split2CompareSequence);
    } 
    return false;
}