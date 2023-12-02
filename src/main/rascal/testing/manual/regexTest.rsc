module testing::manual::regexTest

import testing::util::visualizeGrammars;
import regex::Regex;
import regex::RegexCache;

void main(){ 
    regexText = "([a-z]*\>[A-Z]*!\>.)((\<tag\>test)|(\<tag\>TEST)|REGEX)";
    r = getCachedRegex(parseRegexReduced(regexText));
    visualizeGrammars(<regexText,r>);
}