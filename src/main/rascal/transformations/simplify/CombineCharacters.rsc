module transformations::simplify::CombineCharacters

import Type;
import ParseTree;
import Grammar;
import List;
import String;
import IO;

Grammar combineCharacters(Grammar gr) = visit(gr) {
    case symbols:[*_, \char-class([range(int begin, begin)]), *_] => combineChars(symbols)
};

list[Symbol] combineChars(list[Symbol] parts) {
    buildup = "";
    out = [];
    for(part <- parts) {
        if(\char-class([range(int begin, begin)]) := part) {
            buildup += stringChar(begin);
        } else {
            if(size(buildup) > 0) {
                out += lit(buildup);
                buildup = "";
            }

            out += part;
        }
    }

    if(size(buildup) > 0) {
        out += lit(buildup);
        buildup = "";
    }

    return out;
}