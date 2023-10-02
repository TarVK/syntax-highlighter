module regex::util::GetDisjointCharClasses

import Relation;
import IO;
import ParseTree;
import lang::rascal::grammar::definition::Characters;

import regex::util::charClass;


data CharClassRegion = ccr(CharClass cc, set[CharClass] includes);
alias Event = tuple[int char, set[CharClass] endClasses, set[CharClass] beginClasses];

@doc{
    Given a set of possibly overlapping character classes, obtains all the disjoint character classes that together cover all specified classes and no more, such that every output class is contained within the same subset of character classes of the input. 
    E.g. 
    input = {[a-h], [b-o], [g-l]}
    output = {
        ccr([a-a], {[a-h]}), 
        ccr([b-f], {[a-h], [b-o]}), 
        ccr([g-h], {[a-h], [b-o], [g-l]}), 
        ccr([i-l], {[b-o], [g-l]}), 
        ccr([m-o], {[b-o]})
    }
}
set[CharClassRegion] getDisjointCharClasses(set[CharClass] inClasses) {
    set[CharClassRegion] outClasses = {};

    /* 
        We use a sweep-line algorithm on the character ranges, to efficiently compute ranges even for many characters. 
        This algorithm essentially just computes all overlap between 1 dimensional ranges.
    */

    // Setup the events: starting and stopping character classes
    map[int, tuple[set[CharClass] endClasses, set[CharClass] beginClasses]] eventsMap = ();
    void addEvent(int char, set[CharClass] endClasses, set[CharClass] beginClasses) {
        if(char notin eventsMap) eventsMap[char] = <{}, {}>;
        eventsMap[char].endClasses += endClasses;
        eventsMap[char].beginClasses += beginClasses;
    }
    for(class <- inClasses, range <- class) {
        addEvent(range.begin, {}, {class});
        addEvent(range.end + 1, {class}, {}); // The class ends in the next iteration after end, it's still active during end
    }

    list[Event] events = [
        <char, eventsMap[char].endClasses, eventsMap[char].beginClasses>
        | char <- eventsMap
    ];
    events = sort(events, bool (Event a, Event b) { return a.char < b.char; });

    // Go through the events, and keep track of the active classes at any point
    list[tuple[CharRange, set[CharClass]]] setsPerRange = [];
    set[CharClass] activeClasses = {};
    int previousChar = 0;
    for(<char, endClasses, beginClasses> <- events) {
        previousActiveClasses = activeClasses;
        activeClasses -= endClasses;
        activeClasses += beginClasses;
        if(previousActiveClasses == activeClasses) continue; // May happen if ranges weren't fully merged

        if(previousActiveClasses != {})
            setsPerRange += <range(previousChar, char-1), previousActiveClasses>;
        
        previousChar = char;
    }

    // Create combined character classes from all ranges with the same active class set
    map[set[CharClass], list[CharRange]] rangesPerClassSet = ();
    for(<charRange, classSet> <- setsPerRange) {
        if(classSet notin rangesPerClassSet) rangesPerClassSet[classSet] = [];
        rangesPerClassSet[classSet] += charRange; // Note that the char range order is preserved by using lists
    }

    return {
        ccr(rangesPerClassSet[charClassSet], charClassSet)
        | charClassSet <- rangesPerClassSet
    };
}


// Some testing related functions
void main(){
    ah = [range(97, 104)]; // [a-h] 
    bo = [range(98, 111)]; // [b-o]
    gl = [range(103, 108)]; // [g-l]
    input = {ah, bo, gl};
    expectedOutput = {
        ccr([range(97, 97)], {ah}), 
        ccr([range(98, 102)], {ah, bo}), 
        ccr([range(103, 104)], {ah, bo, gl}), 
        ccr([range(105, 108)], {bo, gl}), 
        ccr([range(109, 111)], {bo})
    };
    actualOutput = getDisjointCharClasses(input);
    println(<expectedOutput == actualOutput, actualOutput>); 


    range1 = [range(84, 90), range(91, 92), range(100, 120)];
    range2 = [range(56, 70), range(110, 120)];
    range3 = [range(111, 130)];
    range4 = [range(105, 120), range(125, 140)];
    input2 = {range1, range2, range3, range4};
    output2 = getDisjointCharClasses(input2);
    checkIncludesSameCharacters(input2, output2);
    checkRegionsAreValid(output2);
    checkRegionsAreDisjoint(output2);
    checkRegionsContainCorrectInputs(input2, output2);
}

@doc {
    Checks whether the given character class regions contain exactly the same characters as the input
}
bool checkIncludesSameCharacters(set[CharClass] input, set[CharClassRegion] output) {
    CharClass union({firstClass, *classes}) = normalize((firstClass | fUnion(it, class) | class <- classes));
    inputClass = union(input);
    outputClass = union({class | ccr(class, _) <- output});
    if(inputClass != outputClass)
        println("Found different total characters: expected <inputClass> but found <outputClass>");
    return inputClass == outputClass;
}

@doc {
    Checks whether the given regions contain valid character classes
}
bool checkRegionsAreValid(set[CharClassRegion] output) {
    for(ccr(class, _) <- output) {
        int prevEnd = -1;
        CharRange prevRange = range(-1, -1);
        for(r:range(begin, end) <- class) {
            if(begin > end) {
                println("Found invalid range: <r>");
                return false;
            }
            if(prevEnd+1 >= begin) {
                println("Found overlapping/out of order/non-merged ranges: <prevRange>,<r>");
                return false;
            }
            prevRange = r;
        }
    }
    return true;
}

@doc {
    Checks whether the given regions in the output are indeed disjoint
}
bool checkRegionsAreDisjoint(set[CharClassRegion] output) {
    for(ccr1:ccr(class1, _) <- output) {
        for(ccr2:ccr(class2, _) <- output, ccr1 != ccr2) {
            if(fIntersection(class1, class2) != []) {
                println("Found overlap: <class1>, <class2>");
                return false;
            }
        }   
    }
    return true;
}

@doc {
    Checks whether the given regions in the output contain all the correct input classes
}
bool checkRegionsContainCorrectInputs(set[CharClass] input, set[CharClassRegion] output) {
    for(ccr(class, includes) <- output) {
        shouldInclude = {include | include <- input, fIntersection(include, class) != []};
        if(includes != shouldInclude){
            println("Region <class> did not contain the right classes: includes <includes>, should include <shouldInclude>");
            return false;
        }
    }
    return true;
}