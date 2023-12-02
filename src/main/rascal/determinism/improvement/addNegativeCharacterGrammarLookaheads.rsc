module determinism::improvement::addNegativeCharacterGrammarLookaheads

import Relation;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import determinism::util::getFollowExpressions;
import determinism::util::removeGrammarTags;
import determinism::improvement::GeneratedMeta;
import regex::RegexStripping;
import regex::Regex;
import regex::RegexCache;
import regex::regexToPSNFA;
import regex::PSNFATools;
import regex::RegexProperties;
import regex::RegexStripping;
import regex::PSNFACombinators;
import Logging;



@doc {
    Adds negative character lookaheads when necessary to deal with keyword overlap
}
ConversionGrammar addNegativeCharacterGrammarLookaheads(ConversionGrammar grammar, set[Regex] characterSets, Logger log) {

    set[tuple[Regex, NFA[State], Regex]] characterSetsWithNFAs = {
        <characters, wordNFA, nlaCharacters>
        | r <- characterSets,
        characters := getCachedRegex(r),
        nlaCharacters := getCachedRegex(\negative-lookahead(empty(), characters)),
        wordNFA := regexToPSNFA(\multi-iteration(characters))
    };

    Maybe[tuple[Regex, bool]] getSuffix(Regex r) {
        for(<characters, wordNFA, nla> <- characterSetsWithNFAs) {
            rNFA = regexToPSNFA(r);

            // Check if this regex could ever apply at the same time as a word
            product = productPSNFA(wordNFA, rNFA, true);
            if(isEmpty(product)) continue;

            // Check if adding the lookahead changes anything
            nlaNFA = regexToPSNFA(\negative-lookahead(r, characters));
            if(nlaNFA == rNFA) continue;

            return just(<nla, false>);
        }
        return nothing();
    }

    return addCustomGrammarLookaheads(
        grammar,
        getSuffix,
        log
    );
}

alias SuffixGetter = Maybe[tuple[
    // The regular expression to be applied within the lookahead
    Regex LARegex, 
    // Whether to skip adding this lookahead if it restricts the language (as opposed to augmenting the lookahead)
    bool skipIfRestrictive
]](
    // The regular expression that the LA would be applied to
    Regex target
);

@doc {
    Adds the given suffix to every regular expression, and might broaden it if it doesn't include all possible cases of next characters. 
}
ConversionGrammar addCustomGrammarLookaheads(ConversionGrammar grammar, SuffixGetter getSuffix, Logger log) {
    log(Section(), "add custom lookahead expressions");
    
    productionMap = {<prod, removeProductionTags(prod)> | <_, prod> <- grammar.productions};
    prods = index({<getWithoutLabel(lDef), <p, pLA>> | <p:convProd(lDef, _), pLA> <- productionMap});

    log(Progress(), "calculating follow expressions");
    scopelessGrammar = getGrammar(grammar.\start, productionMap);
    firstExpressions = getFirstExpressions(scopelessGrammar, true);
    followExpressions = getFollowExpressions(scopelessGrammar, firstExpressions, EOF, 1, true);

    rel[Symbol, ConvProd] outProds = {};
    for(sym <- prods) {
        log(Progress(), "adding lookaheads for <sym>");
        firstExpressions[followExpressionsSym(sym)] = followExpressions[sym];

        for(<p:convProd(lDef, parts), convProd(_, LAparts)> <- prods[sym]) {
            list[ConvSymbol] outParts = [];
            lookaheadParts = LAparts + ref(followExpressionsSym(sym), [], {});

            for(i <- [0..size(parts)]) {
                part = parts[i];
                if(regexp(r) := part) {
                    if(!containsNewline(r), just(<suffix, skipIfRestrictive>) := getSuffix(r)) {
                        log(ProgressDetailed(), "calculating next expressions for regex of <sym> and checking overlap");
                        nextExpressions = getFirstExpressions(lookaheadParts[i+1..], firstExpressions, true);
                        nonCoveredRegexes = {
                            rNext
                            | nfa <- nextExpressions,
                            rNext <- splitRegexUnions(nextExpressions[nfa]),
                            !isSubset(lookahead(r, rNext), concatenation(r, suffix))
                        };

                        if(!skipIfRestrictive || nonCoveredRegexes == {}) {
                            log(ProgressDetailed(), "calculating nextRegex for regex of <sym>");
                            nextExpression = getCachedRegex(
                                reduceAlternation(alternation(suffix + [*nonCoveredRegexes]))
                            );
                            r = getCachedRegex(lookahead(r, meta(nextExpression, generated())));
                        }
                    }

                    outParts += regexp(r);
                } else
                    outParts += part;
            }

            outProds += {<sym, convProd(lDef, outParts)>};
        }
    }

    
    return convGrammar(grammar.\start, outProds);
}

ConversionGrammar getGrammar(Symbol startSym, rel[ConvProd, ConvProd] productionMap) 
    = convGrammar(startSym, {<getWithoutLabel(lDef), p> | <_, p:convProd(lDef, _)> <- productionMap});
data Symbol = followExpressionsSym(Symbol symbol);

set[Regex] splitRegexUnions(Regex r) {
    if(alternation(o1, o2) := removeOuterMeta(r)) {
        return {
            *splitRegexUnions(o1),
            *splitRegexUnions(o2)
        };
    }
    return {getCachedRegex(r)};
}