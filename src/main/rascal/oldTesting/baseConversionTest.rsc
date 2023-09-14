module testing::baseConversionTest


import IO;
import Grammar;
import ParseTree;
import ValueIO;
import lang::json::IO;

import Visualize;
import regex::PSNFA;
import regex::Regex;
import conversion::util::RegexCache;
import conversion::util::Simplification;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::RegexConversion;
import conversion::determinism::Determinism;
import conversion::baseConversion::BaseConversion;
import conversion::shapeConversion::ShapeConversion;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::makePrefixedRightRecursive;
import mapping::intermediate::scopeGrammar::toScopeGrammar;
import mapping::textmate::createTextmateGrammar;
import mapping::common::HighlightGrammarData;



// syntax A = Stmt*;
// syntax Stmt = forIn: "for" "(" Id "in" !>> [a-z0-9] Exp ")" Stmt
//             | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt
//             | iff: "if" "(" Exp ")" Stmt
//             | iffElse: "if" "(" Exp ")" Stmt "else" Stmt
//             | "{" Stmt* "}"
//             | assign: Id "=" Exp;
// syntax Exp = brac: "(" Exp ")"
//            | plus: Exp "+" Exp
//            | inn: Exp "in" !>> [a-z0-9] Exp
//            | id: Id
//            | nat: Natural;
// layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
// keyword KW = "for"|"in"|"if";
// lexical Id  = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
// lexical Natural = [0-9]+ !>> [a-z0-9];

syntax A = Stmt*;
syntax Stmt = forIn: For >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Id In !>> [a-z0-9] Exp ")" Stmt
            | forIter: For >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp Sep Exp Sep Exp ")" Stmt
            | iff: If >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp ")" Stmt
            | iffElse: If >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp ")" Stmt Else Stmt
            | "{" Stmt* "}"
            | assign: Def "=" Exp ";";

syntax Exp = @token="variable.parameter" brac: "(" Exp ")"
           | @token="keyword.operator" add: Exp "+" Exp
           | @token="keyword.operator" mult: Exp "*" Exp
           | @token="keyword.operator" subt: Exp "-" Exp
           | @token="keyword.operator" divide: Exp "/" Exp
           | @token="keyword.operator" equals: Exp "==" Exp
           | @token="keyword.operator" inn: Exp "in" Exp
           | var: Variable
           | string: Str
           | booll: Bool
           | nat: Natural;

lexical If = @token="keyword" "if";
lexical For = @token="keyword" "for";
lexical In = @token="keyword.operator" "in";
lexical Else = @token="keyword" "else";
lexical Sep = @token="entity.name.function" ";";
lexical Def = @scope="variable.parameter" Id;
lexical Variable = @scope="variable" Id;

keyword KW = "for"|"in"|"if"|"true"|"false"|"else";
lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical Natural = @scope="constant.numeric" [0-9]+ !>> [a-z0-9];
lexical Bool = @scope="constant.other" ("true"|"false");
lexical Str =  @scope="string.template" "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @token="constant.character.escape" escape: "\\"![]
             | @scope="meta.embedded.line" @token="punctuation.definition.template-expression" embedded: "${" Layout Exp Layout "}";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @scope="comment.block" "%" !>> "%" ![%]+ "%"
   | @scope="comment.line" "%%" ![\n]* $
   ;

void main() {    
    <cWarnings, conversionGrammar> = toConversionGrammar(#A);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar);
    // inputGrammar = conversionGrammar;
    
    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar);
    <dWarnings, conversionGrammar> = makeDeterministic(conversionGrammar);
    <bWarnings, conversionGrammar> = makeBaseProductions(conversionGrammar);
    // bWarnings = [];

    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    conversionGrammar = relabelGenerated(conversionGrammar);
    inputGrammar = conversionGrammar;

    // stdGrammar = fromConversionGrammar(conversionGrammar);
    <hWarnings, scopeGrammar> = toScopeGrammar(conversionGrammar);
    tmGrammar = createTextmateGrammar(scopeGrammar, highlightGrammarData(
        "highlight",
        [<parseRegexReduced("[(]"), parseRegexReduced("[)]")>],
        scopeName="source.highlight"
    ));

    warnings = cWarnings + rWarnings + sWarnings + dWarnings + bWarnings + hWarnings;
    visualize(insertPSNFADiagrams(removeInnerRegexCache(stripConvSources(<
        fromConversionGrammar(inputGrammar),
        // scopeGrammar,
        tmGrammar,
        warnings
    >))));

    loc output = |project://syntax-highlighter/outputs/tmGrammar.json|;
    writeJSON(output, tmGrammar, indent=4);
}