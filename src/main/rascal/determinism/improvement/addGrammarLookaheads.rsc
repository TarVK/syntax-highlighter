module determinism::improvement::addGrammarLookaheads

import Relation;
import util::Maybe;
import Set;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import determinism::util::getFollowExpressions;
import determinism::util::removeGrammarTags;
import determinism::improvement::GeneratedMeta;
import regex::Regex;
import regex::RegexCache;
import regex::regexToPSNFA;
import regex::PSNFATools;
import regex::RegexProperties;
import regex::RegexStripping;
import regex::NFA;
import regex::PSNFACombinators;
import Logging;

import testing::util::visualizeGrammars;

@doc {
    Adds the given number of layers of lookaheads to all regular expressions in the grammar, ensuring that the described language remains equivalent
}
ConversionGrammar addGrammarLookaheads(ConversionGrammar grammar, Logger log)
    = addGrammarLookaheads(grammar, 1, 1, log);
ConversionGrammar addGrammarLookaheads(ConversionGrammar grammar, int layers, Logger log) 
    = addGrammarLookaheads(grammar, layers, 1, log);
ConversionGrammar addGrammarLookaheads(ConversionGrammar grammar, int layers, int steps, Logger log) {
    log(Section(), "add lookahead expressions");
    rel[ConvProd, ConvProd] productionMap = {<p, p> | <_, p> <- grammar.productions};
    for(i <- [0..layers]) {
        if(layers != 1)
            log(Progress(), "----- starting iteration <i+1> -----");
        productionMap = addGrammarLookaheads(grammar.\start, productionMap, steps, log);
    }

    return getGrammar(grammar.\start, productionMap);
}

ConversionGrammar getGrammar(Symbol startSym, rel[ConvProd, ConvProd] productionMap) 
    = convGrammar(startSym, {<getWithoutLabel(lDef), p> | <_, p:convProd(lDef, _)> <- productionMap});

@doc {
    Adds 1 layer of lookaheads to all regular expressions in the grammar, ensuring that the described language remains equivalent
}
rel[ConvProd, ConvProd] addGrammarLookaheads(Symbol startSym, rel[ConvProd, ConvProd] productionMap, int steps, Logger log) {
    log(Progress(), "calculating follow expressions");

    productionMap = {<originalProd, removeProductionTags(laProd)> | <originalProd, laProd> <- productionMap};
    grammar = getGrammar(startSym, productionMap);
    firstExpressions = getFirstExpressions(grammar, true);
    followExpressions = getFollowExpressions(grammar, firstExpressions, EOF, steps, true);

    prods = Relation::index({<getWithoutLabel(lDef), <p, pLA>> | <p:convProd(lDef, _), pLA> <- productionMap});

    rel[ConvProd, ConvProd] outProds = {};
    for(sym <- prods) {
        log(Progress(), "adding lookaheads for <sym>");
        log(ProgressDetailed(), "calculating followRegex of <sym>");
        followRegexes = sym in followExpressions ? followExpressions[sym] : {};
        <grammar, followSym> =  addRegexesSym(grammar, followRegexes<1>);
        firstExpressions[followSym] = followRegexes;

        for(<p:convProd(lDef, parts), convProd(_, LAparts)> <- prods[sym]) {
            list[ConvSymbol] outParts = [];
            lookaheadParts = LAparts + ref(followSym, [], {});

            for(i <- [0..size(parts)]) {
                part = parts[i];
                if(regexp(r) := part) {
                    if(!containsInternalNewline(r)) {
                        log(ProgressDetailed(), "calculating next expressions for regex of <sym>");
                        nextExpressions = steps == 1 
                            ? getFirstExpressions(lookaheadParts[i+1..], firstExpressions, true)<1>
                            : getFirstNExpressions(grammar, lookaheadParts[i+1..], steps, true)<1>;

                        // Filter out any expressions that are not applicable due to context
                        possibleNextExpressions = {
                            nextExpression 
                            | nextExpression <- nextExpressions,
                            !isEmpty(lookaheadPSNFA(regexToPSNFA(r), regexToPSNFA(nextExpression)))
                        };

                        log(ProgressDetailed(), "calculating nextRegex for regex of <sym>");
                        nextExpression = getCachedRegex(reduceAlternation(alternation([*possibleNextExpressions])));
                        r = getCachedRegex(lookahead(r, meta(nextExpression, generated())));
                    }
                    outParts += regexp(r);
                } else
                    outParts += part;
            }

            outProds += {<p, convProd(lDef, outParts)>};
        }
    }

    return outProds;
}

@doc {
    Adds a symbol to the grammar with a production per regex
}
tuple[ConversionGrammar, Symbol] addRegexesSym(ConversionGrammar grammar, set[Regex] regexes) {
    sym = suffix(regexes);
    grammar.productions += {
        <sym, convProd(sym, [regexp(r)])>
        | r <- regexes
    };

    return <grammar, sym>;
}
data Symbol = suffix(set[Regex]);