module determinism::check::checkClosingExpressionOverlap

import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import determinism::util::getFollowExpressions;
import determinism::util::getAlternations;
import regex::RegexTypes;
import regex::regexToPSNFA;
import regex::PSNFA;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::NFA;
import Warning;

@doc {
    Checks whether the given conversion grammar contains any overlap between alternatives and closing/follow regexes
}
list[Warning] checkClosingExpressionOverlap(ConversionGrammar grammar) {
    list[Warning] out = [];

    allFollowExpressions = getFollowExpressions(grammar);

    map[tuple[NFA[State], NFA[State]], tuple[Regex, Regex, set[ConvProd], set[ConvProd]]] regexes = ();
    for(
        sym <- allFollowExpressions,
        followExpressions := allFollowExpressions[sym],
        followExpr <- followExpressions,
        alternations := getAlternations(grammar, sym),
        altExpr <- alternations<0>
    ) {
        key = <regexToPSNFA(altExpr), regexToPSNFA(followExpr)>;
        if(key in regexes) {
            regexes[key][2] += alternations[altExpr];
            regexes[key][3] += followExpressions[followExpr];
        } else {
            regexes[key] = <altExpr, followExpr, alternations[altExpr], followExpressions[followExpr]>;
        }
    }

    for(
        p <- regexes,
        <altExpr, followExpr, altProds, followProds> := regexes[p]
    ) {
        if(just(overlap) := getOverlap(altExpr, followExpr))
            out += closingOverlap(altExpr, followExpr, altProds, followProds, overlap);
        else if(just(overlap) := getOverlap(followExpr, altExpr))
            out += closingOverlap(altExpr, followExpr, altProds, followProds, overlap);
    }

    return out;
}


@doc {
    Checks whether an extension of rb overlaps with ra. I.e. whether a prefix of ra could also be matched by rb. 
}
Maybe[NFA[State]] getOverlap(Regex ra, Regex rb) {
    nfaA = regexToPSNFA(ra);
    nfaB = regexToPSNFA(rb);
    extensionB = getExtensionNFA(nfaB);
    overlap = productPSNFA(nfaA, extensionB, true);
    if(!isEmpty(overlap)) 
        return just(overlap);
    return nothing();
}