module testing::grammars::LambdaLanguage

syntax Program = Stmt*;
syntax Stmt = forIn: "for" "(" Variable "in" Exp ")" Stmt
            | forIter: "for" "(" Exp Sep Exp Sep Exp ")" Stmt
            | iff: "if" "(" Exp ")" Stmt
            | iffElse: "if" "(" Exp ")" Stmt "else" !>> [a-zA-Z0-9] Stmt
            | "{" Stmt* "}"
            | assign: Variable "=" Exp
            | retrn: "return" Exp
            | Exp;

syntax Exp = brac: "(" Exp ")"
           | add: Exp "+" Exp
           | mult: Exp "*" Exp
           | subt: Exp "-" Exp
           | divide: Exp "/" Exp
           | equals: Exp "==" Exp
           | inn: Exp "in" Exp
           | var: Variable
           | string: Str
           | booll: Bool
           | nat: Natural
           | lambda: Lambda;

// syntax Lambda = ("(" Parameters ")") "=\>" ("{" Stmt * "}") // Brackets can be used to split expressions, which helps for HG conversion
//               | ("(" Parameters ")") "=\>" Exp;

syntax Lambda = ("(" Parameters ")") "=\>" Exp;
syntax Parameters = {Parameter ","}*;

lexical Sep = @token="entity.name.function" ";";
lexical Parameter = @scope="variable.parameter" Id;
lexical Variable = @scope="variable" Id;

keyword KW = "for"|"in"|"if"|"true"|"false"|"else"|"return";
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