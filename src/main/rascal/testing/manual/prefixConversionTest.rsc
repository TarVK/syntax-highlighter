module testing::manual::prefixConversionTest

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;
import conversion::prefixConversion::convertToPrefixed;

// import testing::grammars::SimpleScoped1;

syntax Program = Stmt*;
syntax Stmt = "if" "(" Exp ")" Stmt
            | Exp;
syntax Exp = Id
           | A "a"
           | "b"? B
           | ()>>"c" C
           | "f" F;
syntax A = Exp "A";
syntax B = @categoryTerm="B" "B"
         | "b" B;
syntax C = ()>>"d" D "c"
         | ()>>"d" E "c2"
         | "e" C;
syntax D = ()>>"d" C "D"
         | "d" D;
syntax E = ()>>"e" C "E"
         | "d" E;
syntax F = @category="F" B "c"
         | "f" F;

lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
keyword KW = "for"|"in"|"if"|"true"|"false"|"else";

layout Layout = [\n\ ]* !>> [\n\ ];

void main() {
    log = standardLogger();
    <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
    inputGrammar = fromConversionGrammar(conversionGrammar);
    <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, log);

    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings + rWarnings + pWarnings;
    visualizeGrammars(<
        inputGrammar,
        stdGrammar,
        warnings
    >);
}