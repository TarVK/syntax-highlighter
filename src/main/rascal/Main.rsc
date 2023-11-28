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

syntax Exp = @categoryTerm="variable.parameter" brac: "(" Exp ")"
           | @categoryTerm="keyword.operator" add: Exp "+" Exp
           | @categoryTerm="keyword.operator" mult: Exp "*" Exp
           | @categoryTerm="keyword.operator" subt: Exp "-" Exp
           | @categoryTerm="keyword.operator" divide: Exp "/" Exp
           | @categoryTerm="keyword.operator" equals: Exp "==" Exp
           | @categoryTerm="keyword.operator" inn: Exp "in" Exp
           | var: Variable
           | string: Str
           | booll: Bool
           | nat: Natural;

lexical If = @categoryTerm="keyword" "if";
lexical For = @categoryTerm="keyword" "for";
lexical In = @categoryTerm="keyword.operator" "in";
lexical Else = @categoryTerm="keyword" "else";
lexical Sep = @categoryTerm="entity.name.function" ";";
lexical Def = @category="variable.parameter" Id;
lexical Variable = @category="variable" Id;

keyword KW = "for"|"in"|"if"|"true"|"false"|"else";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical Natural = @category="constant.numeric" [a-z0-9] !<< [0-9]+ !>> [a-z0-9];
lexical Bool = @category="constant.other" [a-z0-9] !<< ("true"|"false") !>> [a-z0-9];
lexical Str =  @category="string.template" "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @categoryTerm="constant.character.escape" escape: "\\"![]
             | @category="meta.embedded.line" @categoryTerm="punctuation.definition.template-expression" embedded: "${" Layout Exp Layout "}";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="comment.block" "%" ![%]+ "%"
   | @category="comment.line" "%%" ![\n]* $
   ;

int main() {
    warnings = convertGrammar(config(
        #Program,
        |project://syntax-highlighter/outputs|,
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
