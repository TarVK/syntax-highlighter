module determinism::improvement::addDynamicGrammarLookaheads

import Relation;
import List;
import util::Maybe;
import util::Benchmark;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import determinism::util::getFollowExpressions;
import determinism::util::removeGrammarTags;
import determinism::improvement::GeneratedMeta;
import regex::RegexStripping;
import regex::Regex;
import regex::PSNFA;
import regex::RegexCache;
import regex::regexToPSNFA;
import regex::PSNFATools;
import regex::RegexProperties;
import regex::RegexStripping;
import regex::PSNFACombinators;
import Logging;

import testing::util::visualizeGrammars;

@doc {
    Adds negative character lookaheads when necessary to deal with keyword overlap,
    and adds automatic positive lookaheads if possible overlap is detected.
}
ConversionGrammar addDynamicGrammarLookaheads(ConversionGrammar grammar, set[Regex] characterSets, Logger log) {
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

    return addCustomAndStandardGrammarLookaheads(
        grammar,
        getSuffix,
        log
    );
}

alias SuffixGetter = Maybe[tuple[
    // The regular expression to be applied within the lookahead
    Regex LARegex, 
    // Whether to fallback to the pure positive lookahead if it restricts the language (as opposed to augmenting the negative lookahead)
    bool positiveIfRestrictive
]](
    // The regular expression that the LA would be applied to
    Regex target
);

@doc {
    Adds the given suffix to every regular expression, and might broaden it if it doesn't include all possible cases of next characters. 
}
ConversionGrammar addCustomAndStandardGrammarLookaheads(ConversionGrammar grammar, SuffixGetter getSuffix, Logger log) {
    log(Section(), "add custom lookahead expressions");
    
    productionMap = {<prod, removeProductionTags(prod)> | <_, prod> <- grammar.productions};
    prods = index({<getWithoutLabel(lDef), <p, pLA>> | <p:convProd(lDef, _), pLA> <- productionMap});

    log(Progress(), "calculating follow expressions");
    scopelessGrammar = getGrammar(grammar.\start, productionMap);
    firstExpressions = getFirstExpressions(scopelessGrammar, true);
    followExpressions = getFollowExpressions(scopelessGrammar, firstExpressions, EOF, true);

    log(Progress(), "calculating possibly overlapping expressions");
    overlap = getPositiveOverlappingExpressions(productionMap);

    rel[Symbol, ConvProd] outProds = {};
    for(sym <- prods) {
        log(Progress(), "adding lookaheads for <sym>");
        firstExpressions[followExpressionsSym(sym)] = sym in followExpressions ? followExpressions[sym] : ();

        for(<p:convProd(lDef, parts), convProd(_, LAparts)> <- prods[sym]) {
            list[ConvSymbol] outParts = [];
            lookaheadParts = LAparts + ref(followExpressionsSym(sym), [], {});

            for(i <- [0..size(parts)]) {
                part = parts[i];
                if(regexp(r) := part) {
                    overlappingRegexes = overlap[r];
                    if(!containsNewline(r) && overlappingRegexes != {}) {
                        log(ProgressDetailed(), "calculating next expressions for regex of <sym> and checking overlap");
                        nextExpressions = getFirstExpressions(lookaheadParts[i+1..], firstExpressions, true);

                        bool applied = false;
                        if(just(<suffix, skipIfRestrictive>) := getSuffix(r)) {
                            nonCoveredRegexes = {
                                rNext
                                | nfa <- nextExpressions,
                                rNext <- splitRegexUnions(nextExpressions[nfa]),
                                !isSubset(lookahead(r, rNext), concatenation(r, suffix))
                            };

                            if(!skipIfRestrictive || nonCoveredRegexes == {}) {
                                log(ProgressDetailed(), "calculating negative nextRegex for regex of <sym>");
                                nextExpression = getCachedRegex(
                                    reduceAlternation(alternation(suffix + [*nonCoveredRegexes]))
                                );
                                r = getCachedRegex(lookahead(r, meta(nextExpression, generated())));
                                applied = true;
                            }
                        }
                        if(!applied) {
                            log(ProgressDetailed(), "calculating positive nextRegex for regex of <sym>");
                            nextExpression = getCachedRegex(
                                reduceAlternation(alternation([*nextExpressions<1>]))
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

@doc {
    Retrieves what reguular expressions could overlap each regular expression in the grammar.

    We exclude overlap with expressions that use character sets that are defined in terms of "all characters except X", since these are usually constructed such that overlap won't occur in this context. Otherwise it's almost guaranteed that every regular expression overlaps with some other expression, making predicting overlap useless.
    We assume that a characterset is negatively defined, if it contains more than half of all possible characters. 
}
map[Regex, set[Regex]] getPositiveOverlappingExpressions(rel[ConvProd, ConvProd] productionMap) {
    map[NFA[State], set[Regex]] expressions = ();
    for(
        <convProd(_, parts), convProd(_, taglessParts)> <- productionMap,
        i <- [0..size(parts)],
        regexp(r) := parts[i],
        regexp(rTagless) := taglessParts[i]
    ) {
        nfa = removeNegativeCharacterSets(regexToPSNFA(rTagless));
        if(nfa in expressions) expressions[nfa] += r;
        else                   expressions[nfa] = {r};
    }

    map[Regex, set[Regex]] out = ();
    for(nfa <- expressions) {
        set[Regex] overlapExp = {};
        for(
            nfa2 <- expressions, 
            nfa != nfa2,
            overlaps(nfa, nfa2)
        ) {
            overlapExp += expressions[nfa2];
        }

        for(exp <- expressions[nfa]) 
            out[exp] = overlapExp;
    }

    return out;
}

@doc {
    Removes all transitions with negative character sets from the mainstates of the nfa
}
NFA[State] removeNegativeCharacterSets(NFA[State] nfa) {
    <_, mainStates, _> = getPSNFApartition(nfa);
    return <
        nfa.initial,
        {
            <from, on, to>
            | <from, on, to> <- nfa.transitions,
            from in mainStates && to in mainStates && character(charClass, _) := on 
                ? !isNegativeClass(charClass) 
                : true
        },
        nfa.accepting, 
        ()
    >;
}

@doc {
    Checks if a character class contains more than half of all possible characters
}
bool isNegativeClass(CharClass charClass) {
    total = 0x10FFFF;
    rangeSum = 0;
    for(range(begin, end) <- charClass) {
        rangeSum  += end - begin + 1;
    }
    return rangeSum  >= total/2;
}