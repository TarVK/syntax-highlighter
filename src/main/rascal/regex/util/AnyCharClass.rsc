module regex::util::AnyCharClass

import ParseTree;

CharClass anyCharClass() = [range(1,0x10FFFF)];
