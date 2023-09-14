module testing::highlightTest

import ParseTree;
import util::LanguageServer;
import util::IDEServices;
import util::Reflective;


syntax A = 'a';
syntax B = @category="" 'b'
        | 'd';
syntax C = @category="C" A C B
        | ;

set[LanguageService] highlightContributions() = {
    parser(parser(#C))
};

void main() {
    registerLanguage(
        language(
            pathConfig(srcs=[|project://syntax-highlighter/src/main/rascal|]),
            "syntax-highlighting", // name of the language
            "hlt", // extension
            "testing::highlightTest", // module to import
            "highlightContributions"
        )
    );
}