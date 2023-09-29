module conversion::shapeConversion::convertToShape

import Set;
import Map;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::transforms::removeUnreachable;
import conversion::util::equality::deduplicateProds;
import conversion::util::makeLookahead;
import conversion::shapeConversion::defineUnion;
import conversion::shapeConversion::defineSequence;
import conversion::shapeConversion::defineClosing;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::shapeConversion::removeRedundantLookaheads;
import conversion::shapeConversion::removeLeftSelfRecursion;
import conversion::shapeConversion::combineOverlap;
import conversion::shapeConversion::carryClosingRegexes;
import conversion::shapeConversion::checkLeftRecursion;
import conversion::shapeConversion::splitSequences;
import conversion::shapeConversion::deduplicateClosings;
import regex::RegexTypes;
import regex::RegexCache;
import Logging;
import Warning;

@doc {
    Makes sure every production has the correct shape, and that there's no overlap between alternatives

    The assumption on the input is:
        - The grammar only contains `ref` and `regexp` conversion symbols
        - Every production is either empty, or starts with `regexp`
        - There are no non-productive loops in the grammar where you can recurse without consuming any characters

    The guarantee on the output is:
        - The language is a broadening of the original language
        - Every production has one of the shapes:
            - `A -> `
            - `A -> X A`
            - `A -> X B Y A`
        - Every reachable symbol has an empty production
        - Per symbol, there are never multiple alternatives applicable at once
        - There are no non-productive loops in the grammar where you can recurse without consuming any characters
}

WithWarnings[ConversionGrammar] convertToShape(ConversionGrammar grammar, Logger log)
    = convertToShape(
        grammar, 
        getCachedRegex(makeLookahead(never())),
        log
    );
WithWarnings[ConversionGrammar] convertToShape(
    ConversionGrammar grammar, 
    Regex eof, 
    Logger log
) {
    log(Section(), "to shape");

    list[Warning] warnings = [];
    <nWarnings, startClosing, grammar> = defineSequence([regexp(eof)], {"EOF"}, grammar, convProd(grammar.\start, []));
    warnings += nWarnings;
    grammar.\start = closed(grammar.\start, startClosing);
    // grammar.\start = closed(unionRec({grammar.\start}), startClosing);

    int i = 0;
    set[Symbol] previouslyDefinedClosings = {};
    while(true) {
        log(Progress(), "----- starting iteration <i+1> -----");

        // Define all undefined unions, referenced in closings
        log(Progress(), "defining unions");
        set[Symbol] definedSymbols = grammar.productions<0>;
        set[Symbol] definedUnions = {};
        set[Symbol] toBeDefinedUnions = {s | s:unionRec(_) <- getReachableSymbols(grammar, true) - definedSymbols};
        while(toBeDefinedUnions != {}) {
            for(union <- toBeDefinedUnions) {
                set[ConvProd] newProds = defineUnion(union, grammar);
                <mWarnings, newProds, grammar> = combineConsecutiveSymbols(newProds, grammar);
                newProds                       = deduplicateProds(newProds);

                warnings += mWarnings;
                grammar.productions += {<union, production> | production <- newProds};
            }

            definedUnions += toBeDefinedUnions;
            definedSymbols = grammar.productions<0>;
            toBeDefinedUnions = {s | s:unionRec(_) <- getReachableSymbols(grammar, true) - definedSymbols};
        }
        log(Progress(), "defined <size(definedUnions)> unions");
        

        // Deduplicate the grammar to get rid of closings that don't need to be defined since we know they are equiavelent to another
        log(Progress(), "deduplicating grammar");
        grammar = deduplicateClosings(grammar, previouslyDefinedClosings + definedUnions);


        // Check if there are any new closings left to be defined
        definedSymbols = grammar.productions<0>;
        set[Symbol] toBeDefinedClosings = {s | s:closed(_, _) <- getReachableSymbols(grammar, false) - definedSymbols};
        if(toBeDefinedClosings == {}) {
            log(Progress(), "no new symbols to define");
            break;
        }


        // Define all undefined but referenced closings
        log(Progress(), "defining closings");
        for(closing <- toBeDefinedClosings) {
            <newProds, isAlias>            = defineClosing(closing, grammar);
            if(!isAlias) {
                <mWarnings, newProds, grammar> = combineConsecutiveSymbols(newProds, grammar);
                newProds                       = removeLeftSelfRecursion(newProds);
                newProds                       = removeRedundantLookaheads(newProds, true);
                <oWarnings, newProds, grammar> = combineOverlap(newProds, grammar);
                newProds                       = removeRedundantLookaheads(newProds, false);
                <sWarnings, newProds, grammar> = splitSequences(newProds, grammar);
                <cWarnings, newProds, grammar> = carryClosingRegexes(newProds, grammar);
                <nWarnings, newProds>          = checkLeftRecursion(newProds, grammar);

                warnings += mWarnings + oWarnings + sWarnings + cWarnings + nWarnings;
            }
            grammar.productions += {<closing, production> | production <- newProds};
        }
        log(Progress(), "defined <size(toBeDefinedClosings)> closings");
        previouslyDefinedClosings = toBeDefinedClosings;

        i += 1;
        // For debugging:
        // if(i>=10) {
        //     println("Force quite");
        //     break;
        // }
    }

    return <warnings, grammar>;
}