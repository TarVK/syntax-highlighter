module testing::robustnessTest

import IO;
import measures::Robustness;

syntax A = @category="A" 'a';
syntax B = @category="B" 'b'
        | @category="D" 'd';
syntax C = @category="C" A C B
        | ;

syntax C2 = @category="C" A C2 B 
        | A C2 "k" B
        | ;

void main() {
    input = [Unchanged("aAaBb"), Insertion("k"), Unchanged("D")];
    int penalty = getRobustnessPenalty(#C, #C2, input);
    println(penalty);

    // println(getCommonTokenization(#C, #C2, input));
}