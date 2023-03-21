module testing::tokenizationTest

import IO;
import Content;
import ParseTree;

import measures::util::Tokenization;
import testing::grammars::LambdaJS;
import util::Highlight;

Content main() {
    text = "// Define natural numbers and boolean constructors
0;
1+ nat;

False;
True;

// Define functions
! True = False;
! False = True;

isOdd 0 = False;
isOdd (1+ x) = !(isOdd x);

output isOdd;";
    tokenization = getTokenization(#start[Program], text);
    return showHighlight(tokenization);
}