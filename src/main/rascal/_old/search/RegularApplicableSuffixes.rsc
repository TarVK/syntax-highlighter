module search::RegularApplicableSuffixes

import Grammar;
import ParseTree;
import List;
import Set;
import IO;
import lang::rascal::format::Grammar;

import search::SuffixGroups;
import search::util::GetDisjointCharClasses;
import transformations::MohriNederhof;

alias ApplicableSuffixes = map[Production, set[SuffixStack]];
alias ApplicableSuffixGroups = map[Production, set[SuffixesGroup]];

ApplicableSuffixGroups getRegularApplicableSuffixGroups(Grammar gr) {
    ApplicableSuffixGroups out = ();
    groups = getSuffixGroups(gr);
    
    for(group <- groups) {
        visit(group){
            case pp(prod, 0): {
                if(prod in out) out[prod] += group;
                else out[prod] = {group};
            }
        };
    }

    return out;
}

ApplicableSuffixes getRegularApplicableSuffixes(Grammar gr) {
    ApplicableSuffixGroups groups = getRegularApplicableSuffixGroups(gr);
    return (prod: {*suffixes | suffixGroup(suffixes, _) <- groups[prod]} | prod <- groups);
}

set[SuffixStack] filterCharacterCompatibilities(Production prod, set[SuffixStack] suffixes, int prefixLength, grammar(_, rules), bool log) {
    return {suffix | suffix <- suffixes && overlaps({suffix}, prod, rules, prefixLength, log)};
}

bool overlaps(set[SuffixStack] stacks, p:prod(_, _, _), map[Symbol sort, Production def] rules, int checkCharCount, bool log) {
    initStacks = stacks;

    set[SuffixStack] sourceStacks = findNextCharacters([pp(p, -1)], rules);
    for(_ <- [0..checkCharCount]) {
        if(log) {
            println("------");
            println(stacks);
            println(sourceStacks);
        }
        if(<filteredSources, filteredStacks> := filterOverlaps(sourceStacks, stacks)){
            // if(size(filteredStacks)==0) {
            //     if(parts==[\char-class([range(97,122)]),Continuation(\iter-seps(\char-class([range(97,122)]),[]))]) {
            //         println("----------");
            //         println({getSuffix(stack) | stack <- initStacks});
            //         println(sourceStacks);
            //         println(stacks);
            //     }
            //     return false;
            // }
            if(size(filteredStacks)==0) return false;

            stacks = {*findNextCharacters(stack, rules) | stack <- filteredStacks};
            sourceStacks = {*findNextCharacters(stack, rules) | stack <- filteredSources};
        }
    }

    return true;
}

tuple[set[SuffixStack], set[SuffixStack]] filterOverlaps(set[SuffixStack] stacksA, set[SuffixStack] stacksB) {
    set[SuffixStack] outA = {};
    set[SuffixStack] outB = {};

    for(stackA <- stacksA) {
        for(stackB <- stacksB) {
            inters = fIntersection(getCurrentCharacter(stackA), getCurrentCharacter(stackB));
            bool overlaps = size(inters) > 0;
            if(overlaps){
                outA += stackA;
                outB += stackB;
            }
        }
    }

    return <outA, outB>;
}

list[Symbol] getSuffix(SuffixStack stack) {
    out = [];
    first = true;
    for(pp(prod(_, parts, _), startI) <- reverse(stack)) {
        rEndI = size(parts);
        rStartI = startI + (first ? 0 : 1);
        if(rStartI < rEndI)
            for(i <- [rStartI..rEndI])
                out += parts[i];
        first = false;
    }
    return out;
}