module conversion::determinism::getFollowExpressions

import ParseTree;
import Relation;

import regex::NFA;
import regex::Regex;
import regex::regexToPSNFA;
import regex::RegexTransformations;
import regex::util::charClass;
import regex::PSNFATools;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;

@doc {
    Given a grammar, for every non-terminal `A` in the grammar, retrieves a set `S` of regular expressions (paired with their sources), such that:
    ∃ a,b ∈ symbol* . ∃ a derivation S =>* a A X b 

    I.e. it retrieves all regular expressions that at some point can be to the right of `A` in a derivation. 
    
    This function assumes every symbol to have an empty production, and that no non-productive left-recursive loops exist.
}
map[Symbol, map[Regex, set[ConvProd]]] getFollowExpressions(ConversionGrammar grammar) {
    prods = index(grammar.productions);

    // Get all possible relevant contexts for a symbol to occur in without recomputing
    set[tuple[Symbol, list[ConvSymbol]]] symbolContexts = {};
    rel[tuple[Symbol, list[ConvSymbol]], ConvProd] symbContextsSources = {};

    for(
        <_, p:convProd(_, parts, _)> <- grammar.productions, 
        [*_, symb(sym, _), *rest] := parts
    ) {
        c = <
            getWithoutLabel(sym), 
            rest
        >;

        symbolContexts += c;
        symbContextsSources += <c, p>;
    }

    // Initialize the output with the start symbol in there
    // EOF = \negative-lookahead(empty(), character(anyCharClass()));
    // rel[Symbol, tuple[Regex, ConvProd]] out = {<
    //     grammar.\start, 
    //     <EOF, convProd(\start(grammar.\start), [symb(grammar.\start, []), regexp(EOF)], {})>
    // >};
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

    // Analyze the follow terminals and loops
    rel[Symbol, Symbol] F = {};
    for(c:<sym, suffixParts> <- symbolContexts) {
        expressions = getFirstExpressions(suffixParts, empty(), prods);
        for(exp <- expressions) {
            if(acceptsEmpty(exp)) {
                <expNonEmpty, expEmpty, expEmptyRestr> = factorOutEmpty(exp);
                exp = expNonEmpty;
                
                if(expEmpty != never() || expEmptyRestr != never())
                    // Indicate that anything that can follow the source of sym, can also follow sym
                    F += {<sym, getWithoutLabel(f)> | convProd(f, _, _) <- symbContextsSources[c]}; 
            } 
            
            if(exp != never()) addOut(sym, exp, symbContextsSources[c]);
        }
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

@doc {
    Given a symbol A and a prefix expression X, it returns a set S of regular expressions, such that:
    (w ∈ L(X A) => ∃ Y ∈ S, p,s ∈ E* . ps = w ∧ p ∈ L(X Y))
    ∧ ∃ Y ∈ S . $e ∈ L(X Y)) => $e ∈ L(X A)

    I.e. it returns a set of expressions such that its union defines possible non-empty prefixes of `X A`, and potentially an empty prefix if L(X A) contains the empty string. 
}
set[Regex] getFirstExpressions(Symbol sym, Regex prefixR, ProdMap prods) {
    set[Regex] out = {};

    for(convProd(_, parts, _) <- prods[sym])
        out += getFirstExpressions(parts, prefixR, prods);

    return out;
}

@doc {
    Given a sequence of symbols `a` and a prefix expression X, it returns a set S of regular expressions, such that:
    (w ∈ L(X a) => ∃ Y ∈ S, p,s ∈ E* . ps = w ∧ p ∈ L(X Y))
    ∧ ∃ Y ∈ S . $e ∈ L(X Y)) => $e ∈ L(X a)

    I.e. it returns a set of expressions such that its union defines possible non-empty prefixes of `X a`, and potentially an empty prefix if L(X a) contains the empty string. 
}
set[Regex] getFirstExpressions(list[ConvSymbol] parts, Regex prefixR, ProdMap prods) {
    set[Regex] out = {};

    Regex prefixed(Regex r) = prefixR == empty() ? r : getCachedRegex(concatenation(prefixR, r));
    for(part <- parts) {
        if(regexp(r) := part) {
            prefixedPart = prefixed(r);
            if(isEmpty(regexToPSNFA(prefixedPart)))
                return out;

            out += prefixedPart;

            prefixR = prefixedPart; // We use this as a new prefix, since it may include a lookahead
            if(!acceptsEmpty(prefixR))
                return out;
        } else if(symb(s, _) := part) {
            firstS = getFirstExpressions(getWithoutLabel(s), prefixR, prods);

            // items in firstS may be empty, but we don't want to ad these empty options to the output yet
            set[Regex] empties = {};
            bool fullEmpty = false;
            for(first <- firstS) {
                <firstNonEmpty, firstEmpty, firstEmptyRstr> = factorOutEmpty(first);
                out += firstNonEmpty;
                if(firstEmpty != never()) empties += firstEmpty;
                if(firstEmptyRestr != never()) empties += firstEmptyRestr;
            }

            prefixR = getCachedRegex(reduceAlternation(alternation([*options])));
            if(!acceptsEmpty(prefixR))
                return out;
        }
    }
    
    // If we reach this point, this production may obtain an empty match, so we add this to the output
    out += prefixR;
    return out;
}