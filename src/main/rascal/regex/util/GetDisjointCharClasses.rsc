module regex::util::GetDisjointCharClasses

import IO;
import ParseTree;
import lang::rascal::grammar::definition::Characters;

import regex::util::charClass;


data CharClassRegion = ccr(CharClass cc, set[CharClass] includes);

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
    for(inClass <- inClasses) {
        inClassRemainder = inClass;
        set[CharClassRegion] newOutClasses = {};
        for(ccr(outClass, parts) <- outClasses) {
            classIntersection = fIntersection(inClassRemainder, outClass);
            if (size(classIntersection) == 0) {
                newOutClasses += ccr(outClass, parts);
            } else {
                outClass = fIntersection(outClass, fComplement(classIntersection));
                if(size(outClass) > 0) newOutClasses += ccr(outClass, parts);
                newOutClasses += ccr(classIntersection, {*parts, inClass});

                inClassRemainder = fIntersection(inClassRemainder, fComplement(classIntersection));
            }
        }

        if(size(inClassRemainder) > 0) newOutClasses += ccr(inClassRemainder, {inClass});
        outClasses = newOutClasses;
    }

    return outClasses;
}

public bool overlaps(CharClass r1, CharClass r2) {
    return size(fIntersection(r1, r2)) > 0;
}

void main(){
    println(getDisjointCharClasses({
        [range(97, 104)],  // [a-h]
        [range(98, 111)],  // [b-o], 
        [range(103, 108)]  // [g-l]
    }));    
}