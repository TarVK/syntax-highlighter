module testing::grammars::SimpleScoped1

syntax Program = Stmt*;
syntax Stmt = forIn: For >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Variable In !>> [a-z0-9] Exp ")" Stmt
            | forIter: For >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp Sep Exp Sep Exp ")" Stmt
            | iff: If >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp ")" Stmt
            | iffElse: If >> ("("|[\ \t\n\r]|"%" !>> "%"|"%%") "(" Exp ")" Stmt Else !>> [0-9a-z] Stmt
            | "{" Stmt* "}"
            | assign: Def "=" Exp ";";

syntax Exp = @token="variable.parameter" brac: "(" Exp ")"
           | @token="keyword.operator" add: Exp "+" Exp
           | @token="keyword.operator" mult: Exp "*" Exp
           | @token="keyword.operator" subt: Exp "-" Exp
           | @token="keyword.operator" divide: Exp "/" Exp
           | @token="keyword.operator" equals: Exp "==" Exp
           | @token="keyword.operator" inn: Exp "in" !>> [0-9a-z] Exp
           | var: Variable
           | string: Str
           | booll: Bool !>> [0-9a-z]
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
lexical Str = @scope="string.template" string: "\"" Char* "\"";
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