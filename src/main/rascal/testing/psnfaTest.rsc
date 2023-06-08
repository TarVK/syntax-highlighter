module testing::psnfaTest

import IO;
import ParseTree;

import regex::NFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFASimplification;


void main() {
    // n = concatPSNFA(charPSNFA("a"), charPSNFA([range(99, 120)]));
    // n = concatPSNFA(
    //     negativeLookaheadPSNFA(
    //         lookbehindPSNFA(
    //             charPSNFA("a"), 
    //             charPSNFA("d")
    //         ),
    //         concatPSNFA(
    //             unionPSNFA(
    //                 charPSNFA([range(97, 110)]), // a-n
    //                 charPSNFA([range(99, 115)]) // c-s
    //             ),
    //             charPSNFA("b")
    //         )
    //     ),
    //     charPSNFA([range(100, 120)]) // d - x
    // ); // == ((d < a) !> (([a-n]|[c-s])b))[d-x] == ((?<=d)a(?!([a-n]|[c-s])b))[d-x]
    // n = concatPSNFA(
    //     negativeLookaheadPSNFA(
    //         negativeLookbehindPSNFA(
    //             charPSNFA("a"), 
    //             concatPSNFA(
    //                 charPSNFA("o"),
    //                 charPSNFA("k")
    //             )
    //         ),
    //         concatPSNFA(
    //             unionPSNFA(
    //                 charPSNFA([range(97, 110)]), // a-n
    //                 charPSNFA([range(99, 115)]) // c-s
    //             ),
    //             charPSNFA("b")
    //         )
    //     ),
    //     charPSNFA([range(100, 120)]) // d - x
    // ); // == ((ok !< a) !> (([a-n]|[c-s])b))[d-x] == ((?<!ok)a(?!([a-n]|[c-s])b))[d-x]
    // n = iterationPSNFA(
    //     relabelSetPSNFA(convertPSNFAtoDFA(relabelIntPSNFA(
    //         relabel(
    //             lookaheadPSNFA(
    //                 charPSNFA([range(97, 110)]),  // a-n
    //                 // charPSNFA("a"),
    //                 concatPSNFA(
    //                     charPSNFA([range(97, 100)]), // b-d
    //                     concatPSNFA(
    //                         charPSNFA([range(98, 100)]), // a-d
    //                         charPSNFA("a")
    //                     )
    //                 )
    //             )
    //         )
    //     )))
    // );
    n = iterationPSNFA(removeUnreachable(relabelSetPSNFA(convertPSNFAtoDFA(relabelIntPSNFA(
            relabel(
                lookaheadPSNFA(
                    charPSNFA([range(97, 110)]),  // a-n
                    // charPSNFA("a"),
                    concatPSNFA(
                        charPSNFA([range(97, 100)]), // a-d
                        // charPSNFA("a")
                        // charPSNFA([range(97, 100)])
                        unionPSNFA(
                            charPSNFA([range(98, 100)]), // b-d
                            charPSNFA("a")
                        )
                    )
                )
            )
        )))));
    // n = relabelIntPSNFA(
    //     relabel(
    //         lookaheadPSNFA(
    //             // charPSNFA([range(97, 110)]),  // a-n
    //             charPSNFA("a"),
    //             charPSNFA("a")
    //         )
    //     )
    // );


    // m = n;
    // m = relabel(n);
    // m = removeEpsilon(relabel(n));
    // m = removeUnreachable(removeDuplicates(removeEpsilon(relabel(n))));
    m = relabel(removeUnreachable(removeDuplicates(removeEpsilon(n))));

    
    nfaText = visualize(m);
    loc pos = |project://syntax-highlighter/outputs/nfa.txt|;
    writeFile(pos, "<nfaText>");
}