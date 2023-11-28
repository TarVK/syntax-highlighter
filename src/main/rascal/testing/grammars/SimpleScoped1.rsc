module testing::grammars::SimpleScoped1

syntax Program = Stmt*;
syntax Stmt = forIn: For >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Variable In !>> [a-z0-9] Exp ")" Stmt
            | forIter: For >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp Sep Exp Sep Exp ")" Stmt
            | iff: If >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp ")" Stmt
            | iffElse: If >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp ")" Stmt Else !>> [0-9a-z] Stmt
            | "{" Stmt* "}"
            | assign: Def "=" Exp ";";

syntax Exp = @categoryTerm="variable.parameter" brac: "(" Exp ")"
           | @categoryTerm="keyword.operator" add: Exp "+" Exp
           | @categoryTerm="keyword.operator" mult: Exp "*" Exp
           | @categoryTerm="keyword.operator" subt: Exp "-" Exp
           | @categoryTerm="keyword.operator" divide: Exp "/" Exp
           | @categoryTerm="keyword.operator" equals: Exp "==" Exp
           | @categoryTerm="keyword.operator" inn: Exp "in" !>> [0-9a-z] Exp
           | var: Variable
           | string: Str
           | booll: Bool !>> [0-9a-z]
           | nat: Natural;

lexical If = @categoryTerm="keyword" "if";
lexical For = @categoryTerm="keyword" "for";
lexical In = @categoryTerm="keyword.operator" "in";
lexical Else = @categoryTerm="keyword" "else";
lexical Sep = @categoryTerm="entity.name.function" ";";
lexical Def = @category="variable.parameter" Id;
lexical Variable = @category="variable" Id;

keyword KW = "for"|"in"|"if"|"true"|"false"|"else";
lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical Natural = @category="constant.numeric" [0-9]+ !>> [a-z0-9];
lexical Bool = @category="constant.other" ("true"|"false");
lexical Str = @category="string.template" string: "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @categoryTerm="constant.character.escape" escape: "\\"![]
             | @category="meta.embedded.line" @categoryTerm="punctuation.definition.template-expression" embedded: "${" Layout Exp Layout "}";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="comment.block" "%" !>> "%" ![%]+ "%"
   | @category="comment.line" "%%" ![\n]* $
   ;