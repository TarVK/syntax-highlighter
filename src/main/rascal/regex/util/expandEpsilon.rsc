module regex::util::expandEpsilon

import Set; 
import IO;

import regex::NFATypes;

set[&T] expandEpsilon(NFA[&T] n, set[&T] states) {
    added = states;
    while(size(added)>0) {
        toStates = n.transitions[added][epsilon()];
        added = toStates - states;
        states += toStates;
    }
    return states;
}