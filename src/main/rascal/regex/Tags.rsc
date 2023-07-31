module regex::Tags

import IO;
import Set;

import util::List;

alias Tags = set[value];
alias TagsClass = set[Tags];


// Note on tagClasses being sets of sets:
// The Tags set (inner set) essentially expresses an AND: all the given tags have to be present
// The TagsClass (outer set) expresses an OR: it may match any of these Tags sets

@doc {
    Checks whether the given tag class includes the given tags
}
bool contains(TagsClass tc, Tags tags) = tags in tc;

@doc {
    Computes the intersection of two tag classes
}
TagsClass intersection(TagsClass tc1, TagsClass tc2) = tc1 & tc2;

@doc {
    Computes the union of the two tag classes
}
TagsClass union(TagsClass tc1, TagsClass tc2) = tc1 + tc2;

@doc {
    Takes the first input class, and removes all elements that are in class two
}
TagsClass subtract(TagsClass tc1, TagsClass tc2) = tc1 - tc2;

@doc {
    Creates a tag class, that represents all tag sets that combine all elements of one tag set of tc1, and all elements of one tag set of tc2
}
TagsClass merge(TagsClass tc1, TagsClass tc2) = {tagSet1 + tagSet2 | tagSet1 <- tc1, tagSet2 <- tc2};

@doc {
    Computes the complement of a tag class, given a universe of tagsets
}
TagsClass complement(TagsClass tc, TagsClass universe) = universe - tc;

@doc {
    Checks whether the given tags class is empty
}
bool isEmpty(TagsClass tc) = size(tc)==0;



data TagsClassRegion = tcr(TagsClass tc, set[TagsClass] includes);

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
set[TagsClassRegion] getDisjointTagsClasses(set[TagsClass] inClasses) {
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

str stringify(TagsClass tc) = stringify(["{<stringify(["<t>" | t <- tags], ";")>}" | tags <- tc], ",");

// A quick test
void main(){
    Tags t1 = {1};
    Tags t2 = {2};
    Tags t3 = {3};
    Tags t4 = {4};
    input1 = {{t1, t2}, {t2, t3}, {t1, t2, t4}};
    input2 = {{t1, t2}, {t1, t2, t3}, {t1, t2, t4}};

    println(getDisjointTagsClasses(input2));
}
