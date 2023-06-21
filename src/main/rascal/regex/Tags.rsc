module regex::Tags

import IO;
import Set;

alias Tags = set[value];

data TagClass = tags(set[Tags] tagSetOptions)       // Any tags set included in this sets of tag sets
              | notTags(set[Tags] tagSetOptions);   // Any tags set NOT included in this sets of tag sets

@doc { The tagclass that accepts any tag }
TagClass anyTag = notTags({});

// Note on tagClasses being sets of sets:
// The Tags set (inner set) essentially expresses an AND: all the given tags have to be present
// The TagClass (outer set) expresses an OR: it may match any of these Tags sets
// Then `notTags` ofc simply adds a negation: it may not match any of these Tags sets exactly

@doc {
    Checks whether the given tag class includes the given tags
}
bool contains(TagClass tc, Tags tags) {
    switch(tc) {
        case tags(options): return tags in options;
        case notTags(options): return !(tags in options);
    };
    return false;
}

data TagsClassRegion = tcr(TagClass tc, set[TagClass] includes);

@doc {
    Computes the intersection of two tag classes
}
TagClass intersection(TagClass tc1, TagClass tc2) {
    switch(<tc1, tc2>) {
        case <tags(t1), tags(t2)>: return tags(t1 & t2);
        case <tags(t1), notTags(t2)>: return tags(t1 - t2);
        case <notTags(t1), tags(t2)>: return tags(t2 - t1);
        case <notTags(t1), notTags(t2)>: return notTags(t1 + t2);
    }
    // Unreachable
    return tags({});
}

@doc {
    Computes the union of the two tag classes
}
TagClass union(TagClass tc1, TagClass tc2) {
    switch(<tc1, tc2>) {
        case <tags(t1), tags(t2)>: return tags(t1 + t2);
        case <tags(t1), notTags(t2)>: return notTags(t2 - t1);
        case <notTags(t1), tags(t2)>: return notTags(t1 - t2);
        case <notTags(t1), notTags(t2)>: return notTags(t1 & t2);
    }
    // Unreachable
    return tags({});
}

@doc {
    Creates a tag class, that represents all tag sets that combine all elements of one tag set of tc1, and all elements of one tag set of tc2
}
TagClass merge(TagClass tc1, TagClass tc2) {
    switch(<tc1, tc2>) {
        case <tags(t1), tags(t2)>: return tags({tagSet1 + tagSet2 | tagSet1 <- t1, tagSet2 <- t2});
        case <tags(t1), notTags(t2)>: return notTags({tagSet2 - tagSet1 | tagSet1 <- t1, tagSet2 <- t2});
        case <notTags(t1), tags(t2)>: return notTags(t1 - t2);
        case <notTags(t1), notTags(t2)>: return notTags(t1 & t2);
    }
    // Unreachable
    return tags({});
}

/*
tags({{1}, {2}}), notTags({{4}, {2, 3}})

should accept:
- {1}
- {2}
- {2, 3} // Can be made by joining {2} in tc1 and {3} in tc2
- {2, 4} // Can be made by joining {2} in tc1 and {2, 4} in tc2
- {1, 2}

should not accept:
- {4}
- {5}

I.e. every set has to contain either 1 or 2, and must be obtaininable by merging with a set not in {{4}, {2, 3}, {1}}. 


notTags({{4}, {2, 3}, {3}})
*/

@doc {
    Computes the complement of two tag classes
}
TagClass complement(TagClass tc) {
    switch(tc) {
        case tags(t): return notTags(t);
        case notTags(t): return tags(t);
    }
    // Unreachable
    return tags({});
}

bool isEmpty(tags(t)) = size(t)==0;
bool isEmpty(notTags(_)) = false;

@doc {
    Takes the first input class, and removes all elements that are in class two
}
TagClass subtract(TagClass tc1, TagClass tc2) = intersection(tc1, complement(tc2));


@doc {
    Given a set of possibly overlapping tag classes, obtains all the disjoint tags classes that together cover exactly the union of all input tags classes

    E.g. (pretending each number is a valid tagset, which it's not)
    input = {tags({1, 2}), tags({2, 3}), notTags({3}), notTags({4, 2})}
    output = {
        tcr(tags({1}), {tags({1, 2}), notTags({3}), notTags({4, 2})})
        tcr(tags({2}), {tags({1, 2}), tags({2, 3}), notTags({3})})
        tcr(tags({3}), {tags({2, 3}), notTags({4, 2})})
        tcr(tags({4}), {notTags({3})})
        tcr(notTags({1, 2, 3, 4}), {notTags({3}), notTags({4, 2})})
    }
}
set[TagsClassRegion] getDisjointTagClasses(set[TagClass] inClasses) {
    set[TagsClassRegion] outClasses = {};
    for(inClass <- inClasses) {
        inClassRemainder = inClass;
        set[TagsClassRegion] newOutClasses = {};
        for(tcr(outClass, parts) <- outClasses) {
            classIntersection = intersection(inClassRemainder, outClass);
            if(isEmpty(classIntersection)) {
                newOutClasses += tcr(outClass, parts);
            } else {
                outClass = subtract(outClass, classIntersection);
                if(!isEmpty(outClass)) newOutClasses += tcr(outClass, parts);
                newOutClasses += tcr(classIntersection, parts + {inClass});

                inClassRemainder = subtract(inClassRemainder, classIntersection);
            }
        }

        if(!isEmpty(inClassRemainder)) newOutClasses += tcr(inClassRemainder, {inClass});
        outClasses = newOutClasses;
    }
    return outClasses;
}

void main(){
    Tags t1 = {1};
    Tags t2 = {2};
    Tags t3 = {3};
    Tags t4 = {4};
    input1 = {tags({t1, t2}), tags({t2, t3}), notTags({t3}), notTags({t4, t2})};
    input2 = {tags({t1, t2}), tags({t2, t3}), notTags({})};
    input3 = {tags({t1}), notTags({t2})};
    input4 = {tags({t1, t2}), notTags({t2, t3})};
    input5 = {notTags({t1, t2}), notTags({t2, t3})};

    println(getDisjointTagClasses(input1));

    // println(complement((tags({}) | union(it, tc) | tc <- input4)));
}