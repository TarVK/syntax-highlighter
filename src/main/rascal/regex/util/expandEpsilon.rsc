module regex::util::expandEpsilon

import Set; 

import regex::NFATypes;

set[&T] expandEpsilon(NFA[&T] n, set[&T] states) {
    added = states;
    while(size(added)>0) {
        newAdded = {};
        for(state <- added) {
            transitions = n.transitions[state];
            for(<epsilon(), to> <- transitions){
                if(to in states) continue;
                newAdded += {to};
                states += {to};
            }
        }
        added = newAdded;
    }
    return states;
}