module regex::util::GetCombinations

import Set;

@doc {
    Given a set A consisting of sets B, obtains all possible sets consisting of one or more choices from every B
}
set[set[&T]] getCombinations(set[set[&T]] options) {
    if(size(options) > 0 && <opts, rest> := takeOneFrom(options)) {
        if(size(rest)==0) return power1(opts);
        restSets = getCombinations(rest);
        return {restSet + opt | opt <- power1(opts), restSet <- restSets};
    }
    return {};
}