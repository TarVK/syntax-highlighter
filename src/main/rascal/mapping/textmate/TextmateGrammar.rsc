module mapping::textmate::TextmateGrammar

data TextmateGrammar = textmateGrammar(
    str name,
    str scopeName,
    list[TextmatePattern] patterns,
    map[str, TextmatePattern] repository = (),
    list[str] fileTypes = [],
    str foldingStart = "",
    str foldingEnd = "",
    str firstLineMatch = ""
);

data TextmatePattern 
    = tokenPattern(
        str match,
        Captures captures
    )
    | scopePattern(
        str begin,
        str end,
        Captures beginCaptures,
        Captures endCaptures,
        list[TextmatePattern] patterns,
        str contentName = ""
    )
    | include(list[TextmatePattern] patterns)
    | include(str include);

alias Captures = map[str, CaptureExp];
data CaptureExp = captureExp(str name);