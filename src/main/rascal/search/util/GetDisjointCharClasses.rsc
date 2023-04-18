module search::util::GetDisjointCharClasses

import ParseTree;
import lang::rascal::grammar::definition::Characters;

@doc{
    Given a set of possibly overlapping character classes, obtains all the disjoint character classes that together cover all specified classes and no more, such that every output class is contained within the same subset of character classes of the input. 
    E.g. 
    input = {[a-h], [b-o], [g-l]}
    output = {[a-a], [b-f], [g-h], [i-l], [m-o]}
}
set[CharClass] getDisjointCharClasses(set[CharClass] inClasses) {
    set[CharClass] outClasses = {};
    for(inClass <- inClasses) {
        set[CharClass] newOutClasses = {};
        for(outClass <- outClasses) {
            intersect = fIntersection(inClass, outClass);
            if (size(intersect) == 0) {
                newOutClasses += outClass;
            } else {
                outClass = fIntersection(outClass, fComplement(intersect));
                if(size(outClass) > 0) newOutClasses += outClass;
                newOutClasses += intersect;

                inClass = fIntersection(inClass, fComplement(intersect));
            }
        }

        if(size(inClass) > 0) newOutClasses += inClass;
        outClasses = newOutClasses;
    }

    return outClasses;
}

public CharClass fIntersection(CharClass r1, CharClass r2) 
    = [ r | r <- intersection(r1,r2), !(r is \empty-range)];

public CharClass fComplement(CharClass r1) 
    = [ r | r <- complement(r1), !(r is \empty-range)];

public bool overlaps(CharClass r1, CharClass r2) {
    return size(fIntersection(r1, r2)) > 0;
}