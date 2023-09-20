module conversion::shapeConversion::convertToShape

import Set;
import Map;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::removeUnreachable;
import conversion::shapeConversion::defineUnion;
import conversion::shapeConversion::defineSequence;
import conversion::shapeConversion::defineClosing;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::shapeConversion::removeRedundantLookaheads;
import conversion::shapeConversion::removeLeftSelfRecursion;
import conversion::shapeConversion::combineOverlap;
import conversion::shapeConversion::carryClosingRegexes;
import conversion::shapeConversion::checkLeftRecursion;
import conversion::shapeConversion::broadenUnions;
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
    = convertToShape(grammar, getCachedRegex(never()), broadenIfReached(), log);
WithWarnings[ConversionGrammar] convertToShape(
    ConversionGrammar grammar, 
    Regex eof, 
    BroadeningBehavior broaden, 
    Logger log
) {
    log(Section(), "to shape");

    list[Warning] warnings = [];
    <nWarnings, startClosing, grammar> = defineSequence([regexp(eof)], {"EOF"}, grammar);
    warnings += nWarnings;
    newStart = closed(grammar.\start, startClosing);
    grammar.\start = newStart;

    int i = 0;
    while(true) {
        set[Symbol] definedSymbols = grammar.productions<0>;

        // Check if there are any new closings left to be defined
        set[Symbol] toBeDefinedClosings = {s | s:closed(_, _) <- getReachableSymbols(grammar, false) - definedSymbols};
        if(toBeDefinedClosings == {}) break;

        // Define all undefined but referenced closings
        for(closing <- toBeDefinedClosings) {
            set[ConvProd] newProds         = defineClosing(closing, grammar);
            mWarnings = oWarnings = cWarnings = nWarnings = []; // TODO: remove after testing; redundant
            <mWarnings, newProds, grammar> = combineConsecutiveSymbols(newProds, grammar);
            newProds                       = removeRedundantLookaheads(newProds, true);
            newProds                       = removeLeftSelfRecursion(newProds);
            <oWarnings, newProds, grammar> = combineOverlap(newProds, grammar);
            newProds                       = removeRedundantLookaheads(newProds, false);
            <cWarnings, newProds, grammar> = carryClosingRegexes(newProds, grammar);
            <nWarnings, newProds>          = checkLeftRecursion(newProds, grammar);

            warnings += mWarnings + oWarnings + cWarnings + nWarnings;
            grammar.productions += {<closing, production> | production <- newProds};
        }
        
        // Prematurely broaden to reduce number of generated symbols: `union(A|convSeq(x))`, `union(A|convSeq(y))` => `union(A|convSeq(x)|convSeq(y))`
        <grammar, broadenings> = broadenUnions(grammar, broaden);

        // Define all undefined unions, referenced in closings
        definedSymbols = grammar.productions<0>;
        set[Symbol] toBeDefinedUnions = {s | s:unionRec(_) <- getReachableSymbols(grammar, true) - definedSymbols};
        for(union <- toBeDefinedUnions) {
            set[ConvProd] newProds = defineUnion(union, grammar);
            grammar.productions += {<union, production> | production <- newProds};
        }
        
        // Deduplicate the grammar to get rid of closings that don't need to be defined since we know they are equiavelent to another
        grammar = deduplicateClosings(grammar, toBeDefinedClosings);

        // Log the progress
        log(Progress(), "defined <size(toBeDefinedClosings)> closings");
        log(Progress(), "defined <size(toBeDefinedUnions)> unions");
        log(Progress(), "broadened <size(broadenings)> unions");

        i += 1;
        if(i>=2) break;
    }

    return <warnings, grammar>;
}