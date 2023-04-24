module search::ApplicableSuffixSearch

import Grammar;
import ParseTree;
import List;
import Set;
import IO;
import lang::rascal::format::Grammar;

import search::SuffixGroups;
import search::util::GetDisjointCharClasses;

alias ApplicableSuffixes = map[Production, set[SuffixStack]];
alias ApplicableSuffixGroups = map[Production, set[SuffixesGroup]];

ApplicableSuffixGroups getApplicableSuffixGroups(Grammar gr) {
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

ApplicableSuffixes getApplicableSuffixes(Grammar gr) {
    ApplicableSuffixGroups groups = getApplicableSuffixGroups(gr);
    return (prod: {*suffixes | suffixGroup(suffixes, _) <- groups[prod]} | prod <- groups);
}

ApplicableSuffixes filterCharacterCompatibilities(ApplicableSuffixes suffixes, grammar(starts, rules)) {
    return (prod: {suffix | suffix <- suffixes[prod] && overlaps(suffix, prod, rules) } 
                | prod <- suffixes);
}

bool overlaps(SuffixStack stack, p:prod(_, _, _), map[Symbol sort, Production def] rules) = overlaps({stack}, p, rules);
bool overlaps(set[SuffixStack] stacks, prod(_, parts, _), map[Symbol sort, Production def] rules) {
    for(symbol <- parts) {
        if(\char-class(cls) := symbol) {
            classes = {getCurrentCharacter(stack) | stack <- stacks};
            if(!overlaps(classes, cls)) return false;

            stacks = {*findNextCharacters(stack, rules) | stack <- stacks};
        } else return true;
    }
    return true;
}

bool overlaps(set[CharClass] classes, CharClass class) {
    for(cls <- classes) {
        bool overlaps = size(fIntersection(cls, class)) > 0;
        if(overlaps) return true;
    }
    return false;
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