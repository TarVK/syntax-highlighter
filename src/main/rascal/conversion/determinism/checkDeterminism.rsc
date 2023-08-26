module conversion::determinism::checkDeterminism

import util::Maybe;
import IO;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;
import conversion::determinism::getFollowExpressions;
import regex::Regex;
import regex::PSNFA;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::NFASimplification;
import regex::detectTagAmbiguity;
import regex::util::charClass;
import Warning;

data Warning = alternativesOverlap(ConvProd production1, ConvProd production2, NFA[State] overlap)
             | extensionOverlap(Regex regex, ConvProd production, NFA[State] longerMatch)
             | closingOverlap(ConvProd alternative, Regex closingExpression, set[ConvProd] closingProductions, NFA[State] overlap)
             | ambiguity(Regex regex, ConvProd production, NFA[tuple[set[State], set[State]]] path);

@doc {
    Checks whether there are any determinism issues in the given grammar
}
list[Warning] checkDeterminism(ConversionGrammar grammar) {
    list[Warning] out = [];
    out += checkExtensionOverlap(grammar);
    out += checkAlternativesOverlap(grammar);
    out += checkClosingExpressionOverlap(grammar);
    out += checkAmbiguity(grammar);
    return out;
}


/*******************************
 * Extension overlap check
 *******************************/
list[Warning] checkExtensionOverlap(ConversionGrammar grammar) {
    list[Warning] out = [];

    for(
        <_, p:convProd(_, parts, _)> <- grammar.productions,
        regexp(r) <- parts,
        just(nfa) := doesSelfOverlap(r)
    ) 
        out += extensionOverlap(r, p, nfa);

    return out;
}

Maybe[NFA[State]] doesSelfOverlap(Regex re) {
    nfa = regexToPSNFA(re);

    // The language followed by any non-empty word
    extension = getExtensionNFA(concatPSNFA(nfa, charPSNFA(anyCharClass())));
    
    overlap = productPSNFA(nfa, extension, true);
    if(!isEmpty(overlap)) 
        return just(overlap);
    return nothing();
}

/*******************************
 * Alternative overlap check
 *******************************/
list[Warning] checkAlternativesOverlap(ConversionGrammar grammar) {
    list[Warning] out = [];

    for(sym <- grammar.productions<0>) {
        alternations = getAlternations(grammar, sym);
        for(
            <alt1, alt1Prod> <- alternations, 
            <alt2, alt2Prod> <- alternations,
            alt1Prod != alt2Prod
        ) {
            if(just(overlap) := getOverlap(alt1, alt2)) 
                out += alternativesOverlap(alt1Prod, alt2Prod, overlap);
        }
    }

    return out;
}

set[tuple[Regex, ConvProd]] getAlternations(ConversionGrammar grammar, Symbol sym) 
    = {<r, p> | p:convProd(_, [regexp(r), *_], _) <- grammar.productions[sym]};

Maybe[NFA[State]] getOverlap(Regex ra, Regex rb) {
    nfaA = regexToPSNFA(ra);
    nfaB = regexToPSNFA(rb);
    extensionB = getExtensionNFA(nfaB);
    overlap = productPSNFA(nfaA, extensionB, true);
    if(!isEmpty(overlap)) 
        return just(overlap);
    return nothing();
}

/*******************************
 * Closing overlap check
 *******************************/
list[Warning] checkClosingExpressionOverlap(ConversionGrammar grammar) {
    list[Warning] out = [];
    allFollowExpressions = getFollowExpressions(grammar);
    for(sym <- allFollowExpressions) {
        alternations = getAlternations(grammar, sym);
        followExpressions = allFollowExpressions[sym];
        for(
            <alt, altProd> <- alternations, 
            <follow, followProds> <- followExpressions
        ) {
            if(just(overlap) := getOverlap(alt, follow))
                out += closingOverlap(altProd, follow, followProds, overlap);
            else if(just(overlap) := getOverlap(follow, alt))
                out += closingOverlap(altProd, follow, followProds, overlap);
        }
    }

    return out;
}

/*******************************
 * Ambiguity check
 *******************************/
list[Warning] checkAmbiguity(ConversionGrammar grammar) {
    list[Warning] out = [];
    for(
        <_, p:convProd(_, parts, _)> <- grammar.productions,
        regexp(r) <- parts,
        just(getAmbiguity) := getTagAmbiguity(regexToPSNFA(r))
    ) 
        out += ambiguity(r, p, getAmbiguity());

    return out;
}