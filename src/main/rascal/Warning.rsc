module Warning

@Doc {
    A format for supplying warnings as output of the algorithm in case we cannot ensure a fully exact conversion
}
data Warning;
alias WithWarnings[&T] = tuple[list[Warning] warnings, &T result];