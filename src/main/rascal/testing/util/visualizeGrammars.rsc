module testing::util::visualizeGrammars

import Visualize;
import regex::PSNFA;
import regex::RegexCache;
import regex::RegexStripping;

@doc {
    Visualizes the given grammars, and adds/removes data to aid debugging
}
void visualizeGrammars(&T grammars) {
    visualize(insertPSNFADiagrams(removeInnerRegexCache(grammars)));
}
