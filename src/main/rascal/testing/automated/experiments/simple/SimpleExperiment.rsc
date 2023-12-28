module testing::automated::experiments::simple::SimpleExperiment

import testing::automated::setup::runExperiment;
import testing::automated::setup::viewGrammar;


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
           | @categoryTerm="keyword.operator" smaller: Exp "\<" Exp
           | @categoryTerm="keyword.operator" greater: Exp "\>" Exp
           | @categoryTerm="keyword.operator" smallerEq: Exp "\<=" Exp
           | @categoryTerm="keyword.operator" greaterEq: Exp "\>=" Exp
           | @categoryTerm="keyword.operator" not: "!" Exp
           | @categoryTerm="keyword.operator" or: Exp "||" Exp
           | @categoryTerm="keyword.operator" and: Exp "&&" Exp
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

   
void main() {
    path = |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/simple|;
    // viewGrammar(#Program, path);
    runExperiment(#Program, path);
}