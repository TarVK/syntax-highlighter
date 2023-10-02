module testing::lookaheadTest

import ValueIO;

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;
import determinism::improvement::addGrammarLookaheads;
import determinism::util::getFollowExpressions;
import determinism::util::removeGrammarTags;
import Warning;

// import testing::grammars::SimpleScoped2;

syntax Program = Stmt*;
syntax Stmt = Id "=" Exp;
syntax Exp = "(" Exp ")"
           | Id
           | Natural;

lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical Natural = @scope="constant.numeric" [0-9]+ !>> [a-z0-9];
keyword KW = "for"|"in"|"if"|"true"|"false"|"else";
layout Layout = WhitespaceAndComment* !>> [\ \n];
lexical WhitespaceAndComment = [\ \n];

void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = true;
    
    log = standardLogger();
    
    ConversionGrammar inputGrammar, conversionGrammar;
    list[Warning] cWarnings, rWarnings;
    if(recalc) {
        <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        inputGrammar = conversionGrammar;
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
        cWarnings = rWarnings = [];
    }

    conversionGrammar = addGrammarLookaheads(conversionGrammar, 2, log);
    // conversionGrammar = removeGrammarTags(conversionGrammar);

    warnings = cWarnings + rWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings,
        getFollowExpressions(inputGrammar, true)
    >);
}