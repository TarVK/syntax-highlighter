module testing::automated::tests::simpleRealistic::SimpleRealisticTest

import Grammar;

import Logging;
import regex::Regex;
import specTransformations::addWordBorders;
import conversion::conversionGrammar::ConversionGrammar;
import determinism::improvement::addDynamicGrammarLookaheads;

import testing::automated::setup::runTest;

syntax Program = Stmt*;
syntax Stmt = forIn: For "(" Variable In Exp ")" Stmt
            | forIter: For "(" Exp Sep Exp Sep Exp ")" Stmt
            | iff: If "(" Exp ")" Stmt
            | iffElse: If "(" Exp ")" Stmt Else Stmt
            | "{" Stmt* "}"
            | exp: Exp ";"
            | throww: Throw Exp ";"
            | tryCatch: Try Stmt Catch "(" Variable ")" Stmt
            | tryFinally: Try Stmt Finally Stmt
            | tryCatchFinally: Try Stmt Catch "(" Variable ")" Stmt Finally Stmt
            | ret: Return ";"
            | ret: Return Exp ";";

syntax Exp = var: Variable
           | string: Str
           | booll: Bool
           | nat: Natural
           | call: Exp LPar {Exp ","}* RPar
           | func: Function "(" {Parameter ","}* ")" "{" Stmt* "}"
           | @token="keyword.operator" lambda: (LPar {Variable ","}* RPar) "=\>" (("{" Stmt* "}") | Exp)
           | @token="variable.parameter" index: Exp "[" Exp "]"
           | @token="variable.parameter" slice: Exp "[" Exp RangeSep Exp"]"
           | @token="variable.parameter" listt: "[" {Exp ","}* "]"
           | brac: LPar Exp RPar
           > @token="keyword.operator" not: "!" Exp
           > left (
                  @token="keyword.operator" divide: Exp "/" Exp
                | @token="keyword.operator" mult: Exp "*" Exp
           )
           > left (
                  @token="keyword.operator" subt: Exp "-" Exp
                | @token="keyword.operator" add: Exp "+" Exp
           )
           > left (
                  @token="keyword.operator" equals: Exp "==" Exp
                | @token="keyword.operator" smaller: Exp "\<" Exp
                | @token="keyword.operator" greater: Exp "\>" Exp
                | @token="keyword.operator" smallerEq: Exp "\<=" Exp
           )
           > left (
                  @token="keyword.operator" greaterEq: Exp "\>=" Exp
                | @token="keyword.operator" or: Exp "||" Exp
                | @token="keyword.operator" and: Exp "&&" Exp
                | @token="keyword.operator" inn: Exp "in" Exp
           )
           > left (
                  @token="keyword.operator" assign: Exp "=" Exp
                | @token="keyword.operator" assignPlus: Exp "+=" Exp
                | @token="keyword.operator" assignSubt: Exp "-=" Exp
           );

lexical RangeSep = @token="keyword.operator" "..";
lexical If = @token="keyword" "if";
lexical For = @token="keyword" "for";
lexical In = @token="keyword.operator" "in";
lexical Else = @token="keyword" "else";
lexical Sep = @token="entity.name.function" ";";
lexical Return = @token="keyword" "return";
lexical Def = @scope="variable.parameter" Id;
lexical Variable = @scope="variable" Id;
lexical Parameter = @scope="variable.parameter" Id;
lexical Function = @token="entity.name.function" "function";
lexical Throw = @token="keyword" "throw";
lexical Try = @token="keyword" "try";
lexical Catch = @token="keyword" "catch";
lexical Finally = @token="keyword" "finally";
lexical LPar = @token="variable.parameter" "(";
lexical RPar = @token="variable.parameter" ")";

keyword KW = "for"|"in"|"if"|"true"|"false"|"else"|"return"|"function"|"throw"|"catch"|"finally"|"try";
lexical Id = ([a-zA-Z0-9] !<< [a-zA-Z][a-zA-Z0-9]* !>> [a-zA-Z0-9]) \ KW;
lexical Natural = @scope="constant.numeric" [a-zA-Z0-9] !<< [0-9]+ !>> [a-zA-Z0-9];
lexical Bool = @scope="constant.other" [a-zA-Z0-9] !<< ("true"|"false") !>> [a-zA-Z0-9];
lexical Str =  @scope="string.template" "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @token="constant.character.escape" escape: "\\"![]
             | @scope="meta.embedded.line" @token="punctuation.definition.template-expression" embedded: "${" Layout Exp Layout "}";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @scope="comment.block" "%" ![%]+ "%"
   | @scope="comment.line" "%%" ![\n]* $
   ;
   
void main() {
    runTest(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/simpleRealistic|, 
        autoTestConfig(
            transformSpec = Grammar(Grammar g) {
                return addWordBorders(
                    g, 
                    [range(48, 57), range(65, 90), range(97, 122)] // 0-9A-Za-z
                );
            },
            addLookaheads = ConversionGrammar (ConversionGrammar conversionGrammar, Logger log) {
                return addDynamicGrammarLookaheads(conversionGrammar, {
                    parseRegexReduced("[a-zA-Z0-9]"),
                    parseRegexReduced("[=+\\-\<\>]")
                }, log);
            }
        )
    );
}