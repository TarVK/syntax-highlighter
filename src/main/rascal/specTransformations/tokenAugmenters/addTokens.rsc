module specTransformations::tokenAugmenters::addTokens

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::wrapRegexScopes;
import specTransformations::productionRetrievers::ProductionRetriever;
import specTransformations::GrammarTransformer;
import regex::Regex;
import regex::PSNFA;
import regex::regexToPSNFA;
import regex::RegexCache;
import regex::PSNFATools;
import Scope;
import Logging;

@doc {
    Adds tokens to the grammar. 
    Adds tokens to all productions specified by the prorudction retriever,
    for regular expressions that match the given form and are of finite size.
    logLabel is used for progress logging
}
GrammarTransformer addTokens(ProductionRetriever productions, Regex form, str token, str logLabel) 
    = addTokens(
        productions,
        bool(Regex regex) {
            if(hasMainLoop(regexToPSNFA(regex))) return false;
            return isSubset(regex, form);
        },
        token,
        logLabel
    );
@doc {
    Adds token to the grammar.
    Adds tokens to all productions specified by the prorudction retriever,
    for regular expressions that match the shouldAddToken predicate.
    logLabel is used for progress logging
}
GrammarTransformer addTokens(ProductionRetriever getProductions, bool(Regex) shouldAddToken, str token, str logLabel) 
    = ConversionGrammar (ConversionGrammar grammar, Logger log) {
        productions = getProductions(grammar);

        ConvSymbol addTokens(Regex r, Symbol sym) {
            log(ProgressDetailed(), "processing regex of <sym>");
            return regexp(wrapRegexScopes(r, [token]));
        }

        log(Section(), "adding <logLabel> tokens");
        rel[Symbol, ConvProd] newProductions = {};
        for(<sym, p:convProd(lDef, parts)> <- grammar.productions) {
            if(p in productions) {
                newProductions += {<
                    sym, 
                    convProd(lDef, visit(parts) {
                        case regexp(r) => addTokens(r, sym) when shouldAddToken(r)
                    })
                >};
            } else newProductions += {<sym, p>};
        }

        grammar.productions = newProductions;
        return grammar;
    };

@doc {
    Checks whether a loop exists within the main states of the NFA
}
bool hasMainLoop(NFA[State] nfa) {
    <_, mainStates, _> = getPSNFApartition(nfa);

    bool hasLoop(State s, set[State] reached) {
        if(s in reached) return s in mainStates;

        reached += s;
        toStates = nfa.transitions[s]<1>;
        for(to <- toStates)
            if(hasLoop(to, reached))
                return true;
        return false;
    }

    return hasLoop(nfa.initial, {});
}