module determinism::util::getFollowExpressions

import ParseTree;
import Relation;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import regex::NFA;
import regex::Regex;
import regex::regexToPSNFA;
import regex::RegexTransformations;
import regex::util::charClass;
import regex::PSNFATools;
import regex::RegexCache;
import regex::RegexProperties;

import Visualize;

@doc {
    Given a grammar, for every non-terminal `A` in the grammar, retrieves a set `S` of regular expressions (paired with their sources), such that:
    - ∀ X ∈ S . ∃ a,b ∈ symbol* . ∃ a derivation Start =>* a A X b 
    - ∀ derivations Start =>* a A X b . ∃ X ∈ S 
    - !stopOnNewline => ∀ X ∈ S . (L(X) ∩ ({(p, $e, s) | p,s ∈ Σ*} \ EOF)) = ∅

    I.e. it retrieves all regular expressions that at some point can be to the right of `A` in a derivation. 
    
    If stopOnNewline is set to true, no new-line will only appear as the last character of any regular expression. 
}
map[Symbol, map[Regex, set[ConvProd]]] getFollowExpressions(ConversionGrammar grammar)
    = getFollowExpressions(grammar, true);
map[Symbol, map[Regex, set[ConvProd]]] getFollowExpressions(ConversionGrammar grammar, bool stopOnNewline) {
    prods = index(grammar.productions);

    // Get all possible relevant contexts for a symbol to occur in without recomputing
    set[tuple[Symbol, list[ConvSymbol]]] symbolContexts = {};
    rel[tuple[Symbol, list[ConvSymbol]], ConvProd] symbContextsSources = {};

    for(
        <_, p:convProd(_, parts)> <- grammar.productions, 
        [*_, ref(sym, _, _), *rest] := parts
    ) {
        c = <
            getWithoutLabel(sym), 
            rest
        >;

        symbolContexts += c;
        symbContextsSources += <c, p>;
    }

    // Initialize the output with the start symbol in there
    map[Symbol, map[Regex, set[ConvProd]]] out = ();
    void addOut(Symbol sym, Regex exp, set[ConvProd] sources) {
        if(sym notin out) out[sym] = ();

        for(exp2 <- out[sym]) {
            if(equals(exp, exp2)) {
                out[sym][exp2] += sources;
                return;
            }
        }

        out[sym][exp] = sources;
    }
    addOut(grammar.\start, EOF, {});

    // Analyze the first terminals and nullable symbols
    rel[Symbol, Symbol] F = {};
    for(c:<sym, suffixParts> <- symbolContexts) {
        exp = getFirstExpression(suffixParts, prods, stopOnNewline, {});
        if(acceptsEmpty(exp)) {
            <expNonEmpty, expEmpty, expEmptyRestr> = factorOutEmpty(exp);
            exp = expNonEmpty;
            
            if(expEmpty != never() || expEmptyRestr != never())
                // Indicate that anything that can follow the source of sym, can also follow sym
                F += {<sym, getWithoutLabel(f)> | convProd(f, _) <- symbContextsSources[c]}; 
        } 
        
        if(exp != never()) addOut(sym, exp, symbContextsSources[c]);
    }


    // Now create the transitive closure of F, to account for right-recursion/nesting in productions
    F = F*;
    for(
        <sym, copySym> <- F, 
        sym != copySym,
        copySym in out,
        exp <- out[copySym]
    ) 
        addOut(sym, exp, out[copySym][exp]);

    return out;
}

public Regex EOF = getCachedRegex(\negative-lookahead(empty(), character(anyCharClass())));
// public Regex EOF = getCachedRegex(character(anyCharClass()));

@doc {
    Given a symbol A, it returns a regular expression X, such that:
    - ∀ (p, w, s) ∈ L(A) .
        ∃ wp,ws ∈ Σ* .
            wp ws = w 
            ∧ (p, wp, ws s) ∈ L(X)
            ∧ (w != $e => wp != $e)
    - !stopOnNewline => 
        ∀ (p, wp, _) ∈ L(X) .
            ∃ w, ws, s ∈ Σ* .
                wp ws = w
                ∧ (p, w, s) ∈ L(A)
                ∧ (wp = $e => w = $e)

    I.e. it returns a regular expression that defines prefixes that match any word in A. If stopOnNewline is not set, it also ensures that no more than any word in A is returned, otherwise this can not be guaranteed.
}
Regex getFirstExpression(Symbol sym, ProdMap prods, bool stopOnNewline, set[Symbol] reached) {
    set[Regex] out = {};

    // Check if this symbol was already reached, if so we recursed and this does not lead to new first-expresisons
    if(sym in reached) 
        return getCachedRegex(never()); // This is already part of the output
    reached += sym;

    for(convProd(_, parts) <- prods[sym])
        out += getFirstExpression(parts, prods, stopOnNewline, reached);

    return getCachedRegex(reduceAlternation(alternation([*out])));
}

@doc {
    Given a sequence of symbols `a`, it returns a regular expression X, such that:
    - ∀ (p, w, s) ∈ L(a) .
        ∃ wp,ws ∈ Σ* .
            wp ws = w 
            ∧ (p, wp, ws s) ∈ L(X)
            ∧ (w != $e => wp != $e)
    - !stopOnNewline => 
        ∀ (p, wp, _) ∈ L(X) .
            ∃ w, ws, s ∈ Σ* .
                wp ws = w
                ∧ (p, w, s) ∈ L(a)
                ∧ (wp = $e => w = $e)

    I.e. it returns a regular expression that defines prefixes that match any word in `a`. If stopOnNewline is not set, it also ensures that no more than any word in `a` is returned, otherwise this can not be guaranteed.
}
Regex getFirstExpression(list[ConvSymbol] parts, ProdMap prods, bool stopOnNewline, set[Symbol] reached) {
    if([first, *rest] := parts) {
        Regex r;
        if(regexp(regex) := first)
            r = regex;
        else if(ref(s, _, _) := first)
            r = getFirstExpression(getWithoutLabel(s), prods, stopOnNewline, reached);

        if(!acceptsEmpty(r)) return r;
        
        follow = getFirstExpression(rest, prods, stopOnNewline, reached);
        followEmpty = acceptsEmpty(follow);

        <rNonEmpty, rEmpty, rEmptyRestr> = factorOutEmpty(r);
        Regex extended;

        if(followEmpty) {
            extended = simplifiedAlternation(rEmpty, rEmptyRestr);
        } else {
            if(
                stopOnNewline,
                containsNewline(rEmptyRestr)
            ) {
                // Dropping the constraint means the language of our regex may contain some entries that aren't part of our input sequence

                extended = follow;
            } else {
                extended = simplifiedConcatenation(
                    simplifiedAlternation(rEmpty, rEmptyRestr),
                    follow                   
                );
            }
        }

        return getCachedRegex(
            simplifiedAlternation(
                rNonEmpty,
                extended
            )
        );
    } else {
        return getCachedRegex(empty());
    }
}