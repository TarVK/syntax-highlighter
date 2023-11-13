module Main

import IO;

import convertGrammar;
import conversion::conversionGrammar::ConversionGrammar;
import Logging;
import determinism::improvement::addDynamicGrammarLookaheads;
import regex::Regex;

syntax Program = Stmt*;
syntax Stmt = forIn: For "(" Variable In Exp ")" Stmt
            | forIter: For "(" Exp Sep Exp Sep Exp ")" Stmt
            | iff: If "(" Exp ")" Stmt
            | iffElse: If "(" Exp ")" Stmt Else !>> [a-zA-Z0-9] Stmt
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
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical Natural = @scope="constant.numeric" [a-z0-9] !<< [0-9]+ !>> [a-z0-9];
lexical Bool = @scope="constant.other" [a-z0-9] !<< ("true"|"false") !>> [a-z0-9];
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

int main() {
    warnings = convertGrammar(config(
        #Program,
        "project://syntax-highlighter/outputs",
        {textmateGrammarOutput()},
        addLookaheads = ConversionGrammar(ConversionGrammar conversionGrammar, Logger log) {
            return addDynamicGrammarLookaheads(conversionGrammar, {
                parseRegexReduced("[a-zA-Z0-9]"),
                parseRegexReduced("[=]")
            }, log);
        }
    ));
    println(warnings);

    return 0;
}
