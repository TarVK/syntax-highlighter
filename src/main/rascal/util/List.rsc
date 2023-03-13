module util::List

list[&T] merge(list[&T] a, list[&T] b) {
    switch(b) {
        case [first, *rest]: return merge(first in a ? a : a + first, rest);
        default: return a;
    }
}
