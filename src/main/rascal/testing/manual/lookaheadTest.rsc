module testing::manual::lookaheadTest

import ValueIO;
import Grammar;

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;
import determinism::improvement::addGrammarLookaheads;
import determinism::improvement::addNegativeCharacterGrammarLookaheads;
import determinism::improvement::addDynamicGrammarLookaheads;
import determinism::util::getFollowExpressions;
import determinism::util::removeGrammarTags;
import regex::Regex;
import regex::regexToPSNFA;
import regex::PSNFACombinators;
import regex::PSNFATools;
import Warning;
import specTransformations::addWordBorders;

// import testing::grammars::SimpleLanguage2;

// syntax Program = Stmt*;
// syntax Stmt = Id "=" Exp;
// syntax Exp = "(" Exp ")"
//            | Id
//            | Natural;

// lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
// lexical Natural = @scope="constant.numeric" [0-9]+ !>> [a-z0-9];
// keyword KW = "for"|"in"|"if"|"true"|"false"|"else";
// layout Layout = WhitespaceAndComment* !>> [\ \n];
// lexical WhitespaceAndComment = [\ \n];


syntax Program = Stmt*;
syntax Stmt = Type Variable "=" Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

syntax Type = \type: TypeVariable
            | ar: Type "[]"
            | apply: Type "\<" {Type ","}+ "\>"
            | @token="primitive" number: "number"
            | @token="primitive" string: "string"
            | @token="primitive" boolean: "bool";

lexical Variable = @scope="variable" Id;
lexical TypeVariable = @scope="type" Id;

keyword KW = "bool"|"number"|"string";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = [\ \t\n\r]* !>> [\ \t\n\r%];

void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = true;

    log = standardLogger();
    
    ConversionGrammar inputGrammar, conversionGrammar;
    list[Warning] cWarnings, rWarnings;
    if(recalc) {
        sourceGrammar = grammar(#Program);
        sourceGrammar = addWordBorders(
            sourceGrammar, 
            [range(48, 57), range(65, 90), range(97, 122)] // 0-9A-Za-z
        );

        <cWarnings, conversionGrammar> = toConversionGrammar(sourceGrammar, log);
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        inputGrammar = conversionGrammar;
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
        cWarnings = rWarnings = [];
    }

    // conversionGrammar = addGrammarLookaheads(conversionGrammar, 2, log);
    // rla = getCachedRegex(parseRegexReduced("!\>[a-zA-Z0-9]"));
    // conversionGrammar = addCustomGrammarLookaheads(conversionGrammar, bool(Regex r){return <rla, false>;}, log);
    // conversionGrammar = addNegativeCharacterGrammarLookaheads(conversionGrammar, {parseRegexReduced("[a-zA-Z0-9]")}, log);
    conversionGrammar = addDynamicGrammarLookaheads(conversionGrammar, {
        parseRegexReduced("[a-zA-Z0-9]"),
        parseRegexReduced("[=+\\-\<\>]")
    }, log);

    warnings = cWarnings + rWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings,
        getFollowExpressions(inputGrammar, true),
        regexToPSNFA(\multi-iteration(parseRegexReduced("[a-zA-Z0-9]")))
    >);
}