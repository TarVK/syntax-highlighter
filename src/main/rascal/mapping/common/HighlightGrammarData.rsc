module mapping::common::HighlightGrammarData

import regex::Regex;

data HighlightGrammarData = highlightGrammarData(
    str name,
    list[tuple[Regex, Regex]] brackets,
    list[str] fileTypes = [],
    str scopeName = "",
    str firstLineMatch = ""
);