module testing::psnfaTest

import IO;
import ParseTree;

import regex::NFA;
import regex::PSNFACombinators;


void main() {
    // n = concatPSNFA(charPSNFA("a"), charPSNFA([range(99, 120)]));
    n = concatPSNFA(
        lookaheadPSNFA(
            lookbehindPSNFA(
                charPSNFA("a"), 
                charPSNFA("d")
            ),
            concatPSNFA(
                unionPSNFA(
                    charPSNFA([range(97, 110)]), 
                    charPSNFA([range(99, 115)])
                ),
                charPSNFA("b")
            )
        ),
        charPSNFA([range(100, 120)])
    );

    
    nfaText = visualize(relabel(n));
    loc pos = |project://syntax-highlighter/outputs/nfa.txt|;
    writeFile(pos, "<nfaText>");
}