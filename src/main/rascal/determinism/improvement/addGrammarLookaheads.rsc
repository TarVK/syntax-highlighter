module determinism::improvement::addGrammarLookaheads

import Relation;
import util::Maybe;
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
import Logging;

@doc {
    Adds the given number of layers of lookaheads to all regular expressions in the grammar, ensuring that the described language remains equivalent
}
ConversionGrammar addGrammarLookaheads(ConversionGrammar grammar, Logger log)
    = addGrammarLookaheads(grammar, 1, log);
ConversionGrammar addGrammarLookaheads(ConversionGrammar grammar, int layers, Logger log) {
    log(Section(), "add lookahead expressions");
    rel[ConvProd, ConvProd] productionMap = {<p, p> | <_, p> <- grammar.productions};
    for(i <- [0..layers]) {
        if(layers != 1)
            log(Progress(), "----- starting iteration <i+1> -----");
        productionMap = addGrammarLookaheads(grammar.\start, productionMap, log);
    }

    return getGrammar(grammar.\start, productionMap);
}

ConversionGrammar getGrammar(Symbol startSym, rel[ConvProd, ConvProd] productionMap) 
    = convGrammar(startSym, {<getWithoutLabel(lDef), p> | <_, p:convProd(lDef, _)> <- productionMap});

@doc {
    Adds 1 layer of lookaheads to all regular expressions in the grammar, ensuring that the described language remains equivalent
}
rel[ConvProd, ConvProd] addGrammarLookaheads(Symbol startSym, rel[ConvProd, ConvProd] productionMap, Logger log) {
    log(Progress(), "calculating follow expressions");

    productionMap = {<originalProd, removeProductionTags(laProd)> | <originalProd, laProd> <- productionMap};
    grammar = getGrammar(startSym, productionMap);
    firstExpressions = getFirstExpressions(grammar, true);
    followExpressions = getFollowExpressions(grammar, firstExpressions, EOF, true);

    prods = index({<getWithoutLabel(lDef), <p, pLA>> | <p:convProd(lDef, _), pLA> <- productionMap});

    rel[ConvProd, ConvProd] outProds = {};
    for(sym <- prods) {
        log(Progress(), "adding lookaheads for <sym>");
        log(ProgressDetailed(), "calculating followRegex of <sym>");
        followRegexes = sym in followExpressions ? followExpressions[sym]<1> : {};
        followRegex = getCachedRegex(reduceAlternation(alternation([*followRegexes])));

        for(<p:convProd(lDef, parts), convProd(_, LAparts)> <- prods[sym]) {
            list[ConvSymbol] outParts = [];
            lookaheadParts = LAparts + regexp(followRegex);

            for(i <- [0..size(parts)]) {
                part = parts[i];
                if(regexp(r) := part) {
                    if(!containsNewline(r)) {
                        log(ProgressDetailed(), "calculating next expressions for regex of <sym>");
                        nextExpressions = getFirstExpressions(lookaheadParts[i+1..], firstExpressions, true)<1>;
                        log(ProgressDetailed(), "calculating nextRegex for regex of <sym>");
                        nextExpression = getCachedRegex(reduceAlternation(alternation([*nextExpressions])));
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