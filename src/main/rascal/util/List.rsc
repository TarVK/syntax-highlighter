module util::List

import List;

@doc {
    Concatenates 2 lists, without adding duplicates of b
}
list[&T] merge(list[&T] a, list[&T] b) {
    switch(b) {
        case [first, *rest]: return merge(first in a ? a : a + first, rest);
        default: return a;
    }
}


str stringify(list[str] values, str sep) = ("" | it + val | val <- intersperse(sep, values));