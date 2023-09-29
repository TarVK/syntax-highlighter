module conversion::shapeConversion::convertToShape

import Set;
import Map;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::transforms::removeUnreachable;
import conversion::util::equality::deduplicateProds;
import conversion::util::makeLookahead;
import conversion::util::Alias;
import conversion::util::BaseNFA;
import conversion::shapeConversion::defineUnion;
import conversion::shapeConversion::defineSequence;
import conversion::shapeConversion::defineClosing;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::shapeConversion::removeRedundantLookaheads;
import conversion::shapeConversion::removeLeftSelfRecursion;
import conversion::shapeConversion::combineOverlap;
import conversion::shapeConversion::carryClosingRegexes;
import conversion::shapeConversion::checkLeftRecursion;
import conversion::shapeConversion::nestSequences;
import conversion::shapeConversion::splitSequences;
import conversion::shapeConversion::deduplicateClosings;
import regex::RegexTypes;
import regex::RegexCache;
import regex::PSNFA;
import regex::regexToPSNFA;
import Logging;
import Warning;

import testing::util::visualizeGrammars;

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
        alwaysSplit(), 
        // neverSplit(), 
        log
    );
WithWarnings[ConversionGrammar] convertToShape(
    ConversionGrammar grammar, 
    Regex eof, 
    SequenceSplitting splitting,
    Logger log
) {
    list[Warning] warnings = [];
    log(Section(), "to shape");


    <nWarnings, startClosing, grammar> = defineSequence([regexp(eof)], {"EOF"}, grammar, convProd(grammar.\start, []));
    warnings += nWarnings;

    if(splitting != neverSplit()) {
        grammar.\start = closed(unionRec({grammar.\start}, regexToPSNFA(eof)), startClosing);
    } else
        grammar.\start = closed(grammar.\start, startClosing);

    int i = 0;
    set[Symbol] prevDefinedClosings = {};
    while(true) {
        log(Progress(), "----- starting iteration <i+1> -----");

        if(splitting != neverSplit()) {
            log(Progress(), "predefining unions");
            <uWarnings, grammar, definedUnions> = preDefineUnions(grammar);
            warnings += uWarnings;
            log(Progress(), "predefined <size(definedUnions)> unions");

            log(Progress(), "deduplicating grammar");
            grammar = deduplicateClosings(grammar, prevDefinedClosings + definedUnions);
        }

        
        log(Progress(), "defining unions");
        <uWarnings, grammar, definedUnions> = defineUnions(grammar, splitting);
        warnings += uWarnings;
        log(Progress(), "defined <size(definedUnions)> unions");
        
        log(Progress(), "deduplicating grammar");
        grammar = deduplicateClosings(grammar, prevDefinedClosings + definedUnions);


        log(Progress(), "defining closings");
        <cWarnings, grammar, definedClosings> = defineClosings(grammar, splitting);
        warnings += cWarnings;
        if(definedClosings=={}) {
            log(Progress(), "no new symbols to define");
            break;
        }
        log(Progress(), "defined <size(definedClosings)> closings");
        prevDefinedClosings = definedClosings;

        i += 1;
        // For debugging:
        // if(i>=4) {
        //     println("Force quite");
        //     break;
        // }
    }

    return <warnings, grammar>;
}

@doc {
    Defines all closings currently in the grammar that aren't defined yet.
    This may create references to new closings that aren't defined yet.
}
tuple[
    list[Warning] warnings, 
    ConversionGrammar grammar, 
    set[Symbol] newlyDefined
] defineClosings(
    ConversionGrammar grammar, 
    SequenceSplitting splitting
) {
    list[Warning] warnings = [];

    set[Symbol] definedSymbols = grammar.productions<0>;
    set[Symbol] toBeDefinedClosings = {s | s:closed(_, _) <- getReachableSymbols(grammar, false) - definedSymbols};

    // Define all undefined but referenced closings
    for(closing <- toBeDefinedClosings) {
        <newProds, symIsAlias>                = defineClosing(closing, grammar);
        if(!symIsAlias) {
            <mWarnings, newProds, grammar> = combineConsecutiveSymbols(newProds, grammar);
            newProds                       = removeLeftSelfRecursion(newProds);
            newProds                       = removeRedundantLookaheads(newProds, true);
            <oWarnings, newProds, grammar> = combineOverlap(newProds, grammar);
            newProds                       = removeRedundantLookaheads(newProds, false);
            <sWarnings, newProds, grammar> = nestSequences(newProds, grammar);
            <cWarnings, newProds, grammar> = carryClosingRegexes(newProds, grammar, splitting != neverSplit());
            <nWarnings, newProds>          = checkLeftRecursion(newProds, grammar);

            warnings += mWarnings + oWarnings + sWarnings + cWarnings + nWarnings;
        }
        grammar.productions += {<closing, production> | production <- newProds};
    }

    return <warnings, grammar, toBeDefinedClosings>;
}


@doc {
    Defines a version of all new unions that can't get broadened because of the empty closing nfa. 
    Whenever references to new undegined unions are created, these will also be defined.
    Therefore the won't be any undefined unions left in the output grammar. 
}
tuple[
    list[Warning] warnings, 
    ConversionGrammar grammar,
    set[Symbol] newlyDefined
] preDefineUnions(ConversionGrammar grammar) {
    list[Warning] warnings = [];

    set[Symbol] newlyDefined = {};
    set[Symbol] definedSymbols = grammar.productions<0>;
    set[Symbol] toBeDefinedUnions = {unionRec(syms, emptyNFA) | unionRec(syms, _) <- getReachableSymbols(grammar, true)} - definedSymbols;
    while(toBeDefinedUnions != {}) {
        for(union:unionRec(_, closingNfa) <- toBeDefinedUnions) {
            <newProds, symIsAlias>                = defineUnion(union, grammar);
            if(!symIsAlias) {
                <mWarnings, newProds, grammar> = combineConsecutiveSymbols(newProds, grammar);
                newProds                       = deduplicateProds(newProds);

                warnings += mWarnings;
            }
            grammar.productions += {<union, production> | production <- newProds};
        }

        newlyDefined += toBeDefinedUnions;
        definedSymbols = grammar.productions<0>;
        toBeDefinedUnions = {unionRec(syms, emptyNFA) | unionRec(syms, _) <- getReachableSymbols(grammar, true)} - definedSymbols;
    }

    return <warnings, grammar, newlyDefined>;
}

@doc {
    Define all unions currently in the grammar that aren't defined yet.
    Whenever references to new undegined unions are created, these will also be defined.
    Therefore the won't be any undefined unions left in the output grammar. 
}
tuple[
    list[Warning] warnings, 
    ConversionGrammar grammar,
    set[Symbol] newlyDefined
] defineUnions(ConversionGrammar grammar, SequenceSplitting splitting) {
    list[Warning] warnings = [];

    set[Symbol] newlyDefined = {};
    set[Symbol] definedSymbols = grammar.productions<0>;
    set[Symbol] toBeDefinedUnions = {s | s:unionRec(_, _) <- getReachableSymbols(grammar, true) - definedSymbols};
    while(toBeDefinedUnions != {}) {
        for(union:unionRec(_, closingNfa) <- toBeDefinedUnions) {
            <newProds, symIsAlias>              = defineUnion(union, grammar);
            if(!symIsAlias) {
                <mWarnings, newProds, grammar> = combineConsecutiveSymbols(newProds, grammar);
                <sWarnings, newProds, grammar> = splitSequences(newProds, closingNfa, grammar, splitting);
                newProds                       = deduplicateProds(newProds);

                warnings += mWarnings + sWarnings;
            }
            grammar.productions += {<union, production> | production <- newProds};
        }

        newlyDefined += toBeDefinedUnions;
        definedSymbols = grammar.productions<0>;
        toBeDefinedUnions = {s | s:unionRec(_, _) <- getReachableSymbols(grammar, true) - definedSymbols};
    }

    return <warnings, grammar, newlyDefined>;
}

