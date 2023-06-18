module regex::util::CreateOrdering

import List;

@doc {
    Creates a full ordering of a graph structure, including the given roots
}
list[&T] createOrdering(set[&T] roots, set[&T](&T) getChildren) {
    set[&T] processing = {};
    set[&T] processed = {};

    list[&T] recCreateOrder(&T n) {
        if (n in processed) return [];
        if (n in processing) throw "Found an illegal cycle involving <n>";
        processing += n;

        children = getChildren(n);
        childOrder = [*recCreateOrder(child) | child <- children];
        ordering = [*childOrder, n];

        processing -= n;
        processed += n;
        return ordering;
    }

    return reverse([*recCreateOrder(r) | r <- roots]);
}