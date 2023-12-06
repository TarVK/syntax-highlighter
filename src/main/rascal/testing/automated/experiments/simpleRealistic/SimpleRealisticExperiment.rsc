module testing::automated::experiments::simpleRealistic::SimpleRealisticExperiment

import convertGrammar;
import testing::automated::setup::runExperiment;

syntax Program = Stmt*;
syntax Stmt = forIn: For "(" Variable In Exp ")" Stmt
            | forIter: For "(" Exp ";" Exp ";" Exp ")" Stmt
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
           | call: Exp "(" {Exp ","}* ")"
           | func: Function "(" {Parameter ","}* ")" "{" Stmt* "}"
           | @categoryTerm="keyword.operator" lambda: ("(" {Variable ","}* ")") "=\>" (("{" Stmt* "}") | Exp)
           | @categoryTerm="variable.parameter" index: Exp "[" Exp "]"
           | @categoryTerm="variable.parameter" slice: Exp "[" Exp RangeSep Exp"]"
           | @categoryTerm="variable.parameter" listt: "[" {Exp ","}* "]"
           | brac: "(" Exp ")"
           > @categoryTerm="keyword.operator" not: "!" Exp
           > left (
                  @categoryTerm="keyword.operator" divide: Exp "/" Exp
                | @categoryTerm="keyword.operator" mult: Exp "*" Exp
           )
           > left (
                  @categoryTerm="keyword.operator" subt: Exp "-" Exp
                | @categoryTerm="keyword.operator" add: Exp "+" Exp
           )
           > left (
                  @categoryTerm="keyword.operator" equals: Exp "==" Exp
                | @categoryTerm="keyword.operator" smaller: Exp "\<" Exp
                | @categoryTerm="keyword.operator" greater: Exp "\>" Exp
                | @categoryTerm="keyword.operator" smallerEq: Exp "\<=" Exp
                | @categoryTerm="keyword.operator" greaterEq: Exp "\>=" Exp
           )
           > left (
                  @categoryTerm="keyword.operator" or: Exp "||" Exp
                | @categoryTerm="keyword.operator" and: Exp "&&" Exp
                | @categoryTerm="keyword.operator" inn: Exp "in" Exp
           )
           > left (
                  @categoryTerm="keyword.operator" assign: Exp "=" Exp
                | @categoryTerm="keyword.operator" assignPlus: Exp "+=" Exp
                | @categoryTerm="keyword.operator" assignSubt: Exp "-=" Exp
           );

lexical RangeSep = @categoryTerm="keyword.operator" "..";
lexical If = @categoryTerm="keyword" [a-zA-Z0-9] !<< "if";
lexical For = @categoryTerm="keyword" [a-zA-Z0-9] !<< "for";
lexical In = @categoryTerm="keyword.operator" "in";
lexical Else = @categoryTerm="keyword" "else" !>> [a-zA-Z0-9];
lexical Return = @categoryTerm="keyword" [a-zA-Z0-9] !<< "return";
lexical Function = @categoryTerm="entity.name.function" [a-zA-Z0-9] !<< "function";
lexical Throw = @categoryTerm="keyword" [a-zA-Z0-9] !<< "throw";
lexical Try = @categoryTerm="keyword" [a-zA-Z0-9] !<< "try";
lexical Catch = @categoryTerm="keyword" "catch";
lexical Finally = @categoryTerm="keyword" "finally";
lexical Def = @category="variable.parameter" Id;
lexical Variable = @category="variable" Id;
lexical Parameter = @category="variable.parameter" Id;

keyword KW = "for"|"in"|"if"|"true"|"false"|"else"|"return"|"function"|"throw"|"catch"|"finally"|"try";
lexical Id = ([a-zA-Z0-9] !<< [a-zA-Z][a-zA-Z0-9]* !>> [a-zA-Z0-9]) \ KW;
lexical Natural = @category="constant.numeric" [a-zA-Z0-9] !<< [0-9]+ !>> [a-zA-Z0-9];
lexical Bool = @category="constant.other" [a-zA-Z0-9] !<< ("true"|"false") !>> [a-zA-Z0-9];
lexical Str =  @category="string.template" "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @categoryTerm="constant.character.escape" escape: "\\"![]
             | @category="meta.embedded.line" @categoryTerm="punctuation.definition.template" embedded: "${" Layout Exp Layout "}";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="comment.block" "%" ![%]+ "%"
   | @category="comment.line" "%%" ![\n]* $
   ;
   
   
void main() {
    runExperiment(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/simpleRealistic|,
        autoTestConfig(outputs={pygmentsGrammarOutput()})
    );
}