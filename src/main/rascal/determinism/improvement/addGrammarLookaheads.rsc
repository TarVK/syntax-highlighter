module determinism::improvement::addGrammarLookaheads

import Relation;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import determinism::util::getFollowExpressions;
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
ConversionGrammar addGrammarLookaheads(ConversionGrammar grammar, int layers, Logger log) {
    log(Section(), "to regular expressions");
    for(i <- [0..layers]) {
        if(layers != 1)
            log(Progress(), "----- starting iteration <i+1> -----");
        grammar = addGrammarLookaheads(grammar, log);
    }
    return grammar;
}

@doc {
    Adds 1 layer of lookaheads to all regular expressions in the grammar, ensuring that the described language remains equivalent
}
ConversionGrammar addGrammarLookaheads(ConversionGrammar grammar, Logger log) {
    log(Progress(), "calculating follow expressions");
    followExpressions = getFollowExpressions(grammar);
    prods = index(grammar.productions);

    rel[Symbol, ConvProd] outProds = {};
    for(sym <- prods) {
        log(ProgressDetailed(), "adding lookaheads for productions of <sym>");
        followRegexes = followExpressions[sym]<0>;

        // Don't calculate follow right away, only calculate if needed
        Maybe[Regex] followRegex = nothing();
        Regex getFollowRegex() {
            if(just(r) := followRegex) return r;
            println("calculating follow");
            r = getCachedRegex(reduceAlternation(alternation([*followRegexes])));
            println("finished calculating follow");
            followRegex = just(r);
            return r;
        }

        for(convProd(lDef, parts) <- prods[sym]) {
            
            list[ConvSymbol] outParts = [];
            for(i <- [0..size(parts)]) {
                part = parts[i];
                if(regexp(r) := part) {
                    if(!containsNewline(r)) {
                        lookaheadParts = parts + regexp(getFollowRegex());
                        nextExpr = getFirstExpression(lookaheadParts[i+1..], prods, true, {});
                        println("calculating la");
                        r = getCachedRegex(lookahead(r, removeTags(nextExpr)));
                        println("finished calculating la");
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