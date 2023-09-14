module testing::precisionTest

import IO;
import measures::Precision;

syntax A = @category="A" 'a'*;
syntax B = @category="B" 'b'
        | @category="D" 'd';
syntax C = @category="C" A C B
        | ;

syntax C2 = @category="C" @category="D" A C2 B
        | ;


void main() {
    int penalty = getPrecisionPenalty(#C, #C2, "aAaBbD");
    println(penalty);
}