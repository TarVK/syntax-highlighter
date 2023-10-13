module regex::regexToSingleCaptureRegex

import IO;

import regex::RegexTypes;
import regex::RegexProperties;

@doc {
    Transforms the givern regular expression into one that mirrors the capture group semantics of common regex engines.
    This function assumes tags to be unique, as is the case for capture groups. 
}
Regex regexToSingleCaptureRegex(Regex regex) {
    Regex zeroOrOneMatchIteration(Regex r, value t) 
        = alternation(
            oneMatchIteration(r, t),
            deleteTag(\multi-iteration(r), t)
        );

    return visit(regex) {
        case \multi-iteration(r): {
            tags = {*t | /mark(t, _) := r};
            if({t1, *tr} := tags) {
                insert (
                    zeroOrOneMatchIteration(r, t1)
                    | intersection(it, zeroOrOneMatchIteration(r, nt))
                    | nt <- tr
                );
            } else 
                insert \multi-iteration(r);
        }
    }
}

Regex iteration(Regex r) = alternation(empty(), \multi-iteration(r));
Regex oneMatchIteration(Regex r, value t) 
    = concatenation(
        concatenation(
            filterTags(iteration(r)),
            keepTag(r, t)
        ),
        deleteTag(iteration(r), t)
    );

@doc {
    Removes all tag assignments from the given regular expression, but keeps all expressions in tact
}
Regex filterTags(Regex regex) = visit(regex) {
    case mark(_, r) => r
};

@doc {
    Extracts a regular expression from the given expression that assigns the given tag exactly once
}
Regex keepTag(Regex regex, value t) = top-down visit(regex) {
    case alternation(o1, o2): {
        if(/mark(tags, _) := o1, t in tags) insert o1;
        if(/mark(tags, _) := o2, t in tags) insert o2;
        insert alternation(o1, o2);
    }
    case mark(tags, r): {
        if(t in tags) insert mark({t}, r);
        insert r;
    }
    case \multi-iteration(r): {
        if(/mark(tags, _) := r, t in tags)
            insert oneMatchIteration(r, t);
        else 
            insert \multi-iteration(r);
    }
};

@doc {
    Extracts a regular expression that matches everything in the original expression (without tags), except anything that requires matching the specified tag
}
Regex deleteTag(Regex regex, value t) = visit(regex) {
    case mark(tags, r): {
        if(t in tags) insert never();
        insert r;
    }
};