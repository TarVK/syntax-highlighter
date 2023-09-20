module testing::shapeConversionTest

import ValueIO;

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;
import conversion::prefixConversion::convertToPrefixed;
import conversion::shapeConversion::convertToShape;
import Warning;

// import testing::grammars::SimpleScoped1;

syntax Program = Stmt*;
syntax Stmt = "if" "(" Exp ")" Stmt
            | Exp;
syntax Exp = Id
           | "(" Exp ")";

lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
keyword KW = "for"|"in"|"if"|"true"|"false"|"else";

layout Layout = [\n\ ]* !>> [\n\ ];

void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = false;

    log = standardLogger();
    list[Warning] cWarnings, rWarnings, pWarnings, sWarnings;
    ConversionGrammar inputGrammar, conversionGrammar;
    if(recalc) {
        <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        inputGrammar = conversionGrammar;
        <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, log);
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
        cWarnings = rWarnings = pWarnings = [];
    }

    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, log);

    warnings = cWarnings + rWarnings + pWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings
    >);
}