# Deriving Syntax Highlighting Grammars from Context-Free Grammars

This repository contains the code developed during my master thesis research, which attempts to solve the problem of formal languages having to maintain multiple highlight grammars and a parsing grammar. The targeted highlighting grammar formats are that of [TextMate](https://macromates.com/manual/en/language_grammars), [Monarch](https://microsoft.github.io/monaco-editor/monarch.html), [Ace](https://ace.c9.io/#nav=higlighter), and [Pygments](https://pygments.org/docs/lexerdevelopment/). The parsing grammar formalism we considered is [Rascal's context free grammar](https://www.rascal-mpl.org/docs/Rascal/Declarations/SyntaxDefinition/). These grammars allow for `@category` annotations for productions, such that they can both be used for parsing and syntax highlighting. Our research attempts to derive syntax highlighters in any of the four mentioned formats, from the specification Rascal grammar. In some situations this is done perfectly by our algorithm, but in other cases it may fail, and it might even be impossible to translate the specification perfectly due to limitations of the highlighting grammars themselves. [`report.pdf`](report.pdf) contains more information about the approach taken in this research. This report contains some terminology that is inconsistent with the code, see [terminology fixes](#)

## Example 

Below is an example of a Rascal grammar that our algorithm was able to transform to a TextMate grammar perfectly:

```haskell
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
```

The generated TextMate grammar, which tokenizes exactly according to specification, looks as follows:
<details>
  <summary>Show large json file</summary>

```json
{
    "name": "test",
    "scopeName": "source.test",
    "patterns": [{"include": "#C5"}],
    "repository": {
        "C12": {
            "patterns": [
                {"include": "#T"},
                {"include": "#iffElse,iff7"},
                {"include": "#S"},
                {"include": "#S1"},
                {"include": "#assign"},
                {"include": "#forIter,forIn"}
            ]
        },
        "C14": {
            "patterns": [
                {"include": "#T"},
                {"include": "#empty"},
                {"include": "#iffElse"},
                {"include": "#S1"},
                {"include": "#S"},
                {"include": "#forIter,forIn"},
                {"include": "#iffElse,iff"},
                {"include": "#assign"}
            ]
        },
        "C15": {
            "patterns": [
                {"include": "#smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller"},
                {"include": "#not"},
                {"include": "#T"},
                {"include": "#empty"},
                {"include": "#forIter"},
                {"include": "#S"},
                {"include": "#forIter,forIn2"},
                {"include": "#S2"},
                {"include": "#brac"},
                {"include": "#nat,booll,var,forIn2"}
            ]
        },
        "C16": {
            "patterns": [
                {"include": "#empty"},
                {"include": "#T"},
                {"include": "#S"},
                {"include": "#S1"},
                {"include": "#forIter,forIn"},
                {"include": "#iffElse,iff1"},
                {"include": "#assign"}
            ]
        },
        "C17": {"include": "#single,multiple"},
        "C19": {
            "patterns": [
                {"include": "#T"},
                {"include": "#empty"},
                {"include": "#S"},
                {"include": "#forIter,forIn3"}
            ]
        },
        "iffElse,iff6": {
            "begin": "\\(",
            "end": "(?=\\})",
            "patterns": [{"include": "#C7"}]
        },
        "iffElse,iff7": {
            "begin": "(if)(?=\\%\\%[^\\n]*$|[\\t-\\n\\r ]|\\%|\\()",
            "end": "(?=\\})",
            "beginCaptures": {"1": {"name": "keyword"}},
            "patterns": [{"include": "#C10"}]
        },
        "smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller": {
            "match": "(?:(\\+|\\>|\\=\\=|\\|\\||\\<\\=|\\<|\\/|\\*|\\-|\\&\\&|\\>\\=|in))(?=\\!|(?<![0-9a-z])[0-9]+(?![0-9a-z])|\\%\\%[^\\n]*$|(?<![0-9a-z])(?:false|true)(?![0-9a-z])|[\\t-\\n\\r ]|\\(|(?!(?<![0-9a-z])(?:else|for|false|true|in|if)(?![0-9a-z]))(?<![0-9a-z])[a-z][0-9a-z]*(?![0-9a-z])|\\\"|\\%)",
            "captures": {"1": {"name": "keyword.operator"}}
        },
        "C20": {"include": "#single,multiple1"},
        "forIter": {
            "begin": "(\\;)",
            "end": "(\\;)",
            "beginCaptures": {"1": {"name": "entity.name.function"}},
            "endCaptures": {"1": {"name": "entity.name.function"}},
            "patterns": [{"include": "#C2"}]
        },
        "assign1": {
            "begin": "\\=(?=\\!|(?<![0-9a-z])[0-9]+(?![0-9a-z])|\\%\\%[^\\n]*$|(?<![0-9a-z])(?:false|true)(?![0-9a-z])|[\\t-\\n\\r ]|\\(|(?!(?<![0-9a-z])(?:else|for|false|true|in|if)(?![0-9a-z]))(?<![0-9a-z])[a-z][0-9a-z]*(?![0-9a-z])|\\\"|\\%)",
            "end": "(?=\\;)",
            "patterns": [{"include": "#C2"}]
        },
        "C10": {
            "patterns": [
                {"include": "#T"},
                {"include": "#iffElse,iff6"},
                {"include": "#S"}
            ]
        },
        "iffElse": {
            "match": "(else(?![0-9A-Za-z]))",
            "captures": {"1": {"name": "keyword"}}
        },
        "C11": {
            "patterns": [
                {"include": "#escape,dollarChar,char"},
                {"include": "#embedded"}
            ]
        },
        "forIter,forIn": {
            "begin": "(for)(?=\\(|\\%\\%[^\\n]*$|[\\t-\\n\\r ]|\\%)",
            "end": "\\)",
            "beginCaptures": {"1": {"name": "keyword"}},
            "patterns": [{"include": "#C13"}]
        },
        "C13": {
            "patterns": [
                {"include": "#T"},
                {"include": "#forIter,forIn4"},
                {"include": "#S"}
            ]
        },
        "escape,dollarChar,char": {
            "match": "\\$(?!\\{)|(\\\\.)|[^\\\"\\$\\\\]",
            "captures": {"1": {"name": "constant.character.escape"}}
        },
        "C18": {
            "patterns": [
                {"include": "#empty"},
                {"include": "#T"},
                {"include": "#iffElse,iff4"},
                {"include": "#S"}
            ]
        },
        "embedded": {
            "begin": "((\\$\\{))",
            "end": "((\\}))",
            "beginCaptures": {
                "1": {"name": "meta.embedded.line"},
                "2": {"name": "punctuation.definition.template-expression"}
            },
            "endCaptures": {
                "1": {"name": "meta.embedded.line"},
                "2": {"name": "punctuation.definition.template-expression"}
            },
            "patterns": [{"include": "#C2"}],
            "contentName": "meta.embedded.line"
        },
        "C0": {
            "patterns": [
                {"include": "#T"},
                {"include": "#iffElse,iff5"},
                {"include": "#S"}
            ]
        },
        "empty": {
            "match": "(?:x(?<!x))"
        },
        "C1": {
            "patterns": [
                {"include": "#not"},
                {"include": "#nat,booll,var,forIn1"},
                {"include": "#smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller"},
                {"include": "#T"},
                {"include": "#S"},
                {"include": "#brac"},
                {"include": "#S2"},
                {"include": "#forIter"}
            ]
        },
        "forIter,forIn1": {
            "begin": "(for)(?=\\(|\\%\\%[^\\n]*$|[\\t-\\n\\r ]|\\%)",
            "end": "(?:x(?<!x))",
            "beginCaptures": {"1": {"name": "keyword"}},
            "patterns": [{"include": "#C19"}]
        },
        "C2": {
            "patterns": [
                {"include": "#nat,booll,var,forIn1"},
                {"include": "#not"},
                {"include": "#T"},
                {"include": "#smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller"},
                {"include": "#S"},
                {"include": "#S2"},
                {"include": "#brac"}
            ]
        },
        "assign": {
            "begin": "(?!(?<![0-9a-z])(?:else|for|false|true|in|if)(?![0-9a-z]))((?<![0-9a-z])[a-z][0-9a-z]*(?![0-9a-z]))",
            "end": "\\;",
            "beginCaptures": {"1": {"name": "variable.parameter"}},
            "patterns": [{"include": "#C3"}]
        },
        "forIter,forIn2": {
            "begin": "\\)",
            "end": "(?:x(?<!x))",
            "patterns": [{"include": "#C16"}]
        },
        "C3": {
            "patterns": [
                {"include": "#T"},
                {"include": "#assign1"},
                {"include": "#S"}
            ]
        },
        "forIter,forIn3": {
            "begin": "\\(",
            "end": "(?:x(?<!x))",
            "patterns": [{"include": "#C15"}]
        },
        "C4": {
            "patterns": [
                {"include": "#T"},
                {"include": "#iffElse"},
                {"include": "#iffElse,iff"},
                {"include": "#forIter,forIn"},
                {"include": "#S"},
                {"include": "#assign"},
                {"include": "#S1"}
            ]
        },
        "forIter,forIn4": {
            "begin": "\\(",
            "end": "(?=\\))",
            "patterns": [{"include": "#C6"}]
        },
        "C5": {
            "patterns": [
                {"include": "#T"},
                {"include": "#empty"},
                {"include": "#forIter,forIn1"},
                {"include": "#assign"},
                {"include": "#S1"},
                {"include": "#S"},
                {"include": "#iffElse,iff1"}
            ]
        },
        "brac": {
            "begin": "(\\()",
            "end": "(\\))",
            "beginCaptures": {"1": {"name": "variable.parameter"}},
            "endCaptures": {"1": {"name": "variable.parameter"}},
            "patterns": [{"include": "#C2"}]
        },
        "iffElse,iff1": {
            "begin": "(if)(?=\\%\\%[^\\n]*$|[\\t-\\n\\r ]|\\%|\\()",
            "end": "(?:x(?<!x))",
            "beginCaptures": {"1": {"name": "keyword"}},
            "patterns": [{"include": "#C18"}]
        },
        "iffElse,iff2": {
            "begin": "\\)",
            "end": "(?=\\})",
            "patterns": [{"include": "#C4"}]
        },
        "not": {
            "match": "(\\!)",
            "captures": {"1": {"name": "keyword.operator"}}
        },
        "S": {
            "begin": "(\\%)(?=[^\\%])",
            "end": "(\\%)",
            "beginCaptures": {"1": {"name": "comment.block"}},
            "endCaptures": {"1": {"name": "comment.block"}},
            "patterns": [{"include": "#C20"}],
            "contentName": "comment.block"
        },
        "C6": {
            "patterns": [
                {"include": "#not"},
                {"include": "#T"},
                {"include": "#smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller"},
                {"include": "#brac"},
                {"include": "#S2"},
                {"include": "#nat,booll,var,forIn"},
                {"include": "#forIter"},
                {"include": "#S"}
            ]
        },
        "nat,booll,var,forIn": {
            "begin": "(?!(?<![0-9a-z])(?:else|for|false|true|in|if)(?![0-9a-z]))((?<![0-9a-z])[a-z][0-9a-z]*(?![0-9a-z]))|((?<![0-9a-z])(?:false|true)(?![0-9a-z]))|((?<![0-9a-z])[0-9]+(?![0-9a-z]))",
            "end": "(?=\\))",
            "beginCaptures": {
                "1": {"name": "variable"},
                "2": {"name": "constant.other"},
                "3": {"name": "constant.numeric"}
            },
            "patterns": [{"include": "#C1"}]
        },
        "iffElse,iff3": {
            "begin": "\\)",
            "end": "(?:x(?<!x))",
            "patterns": [{"include": "#C14"}]
        },
        "single,multiple": {
            "match": "[^\\%]"
        },
        "T": {
            "match": "[\\t-\\n\\r ]|(\\%\\%[^\\n]*$)",
            "captures": {"1": {"name": "comment.line"}}
        },
        "C7": {
            "patterns": [
                {"include": "#nat,booll,var,forIn1"},
                {"include": "#T"},
                {"include": "#not"},
                {"include": "#smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller"},
                {"include": "#S2"},
                {"include": "#S"},
                {"include": "#iffElse,iff2"},
                {"include": "#brac"}
            ]
        },
        "C8": {
            "patterns": [
                {"include": "#T"},
                {"include": "#not"},
                {"include": "#nat,booll,var,forIn1"},
                {"include": "#empty"},
                {"include": "#smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller"},
                {"include": "#forIter"},
                {"include": "#S2"},
                {"include": "#S"},
                {"include": "#brac"},
                {"include": "#forIter,forIn2"}
            ]
        },
        "iffElse,iff4": {
            "begin": "\\(",
            "end": "(?:x(?<!x))",
            "patterns": [{"include": "#C9"}]
        },
        "C9": {
            "patterns": [
                {"include": "#not"},
                {"include": "#empty"},
                {"include": "#nat,booll,var,forIn1"},
                {"include": "#T"},
                {"include": "#smallerEq,add,or,greaterEq,inn,mult,and,divide,greater,equals,subt,smaller"},
                {"include": "#iffElse,iff3"},
                {"include": "#S2"},
                {"include": "#brac"},
                {"include": "#S"}
            ]
        },
        "iffElse,iff5": {
            "begin": "\\(",
            "end": "(?=\\))",
            "patterns": [{"include": "#C2"}]
        },
        "nat,booll,var,forIn1": {
            "match": "(?!(?<![0-9a-z])(?:else|for|false|true|in|if)(?![0-9a-z]))((?<![0-9a-z])[a-z][0-9a-z]*(?![0-9a-z]))|((?<![0-9a-z])(?:false|true)(?![0-9a-z]))|((?<![0-9a-z])[0-9]+(?![0-9a-z]))",
            "captures": {
                "1": {"name": "variable"},
                "2": {"name": "constant.other"},
                "3": {"name": "constant.numeric"}
            }
        },
        "single,multiple1": {
            "begin": "[^\\%]",
            "end": "(?=\\%)",
            "patterns": [{"include": "#C17"}]
        },
        "S1": {
            "begin": "\\{",
            "end": "\\}",
            "patterns": [{"include": "#C12"}]
        },
        "nat,booll,var,forIn2": {
            "begin": "(?!(?<![0-9a-z])(?:else|for|false|true|in|if)(?![0-9a-z]))((?<![0-9a-z])[a-z][0-9a-z]*(?![0-9a-z]))|((?<![0-9a-z])(?:false|true)(?![0-9a-z]))|((?<![0-9a-z])[0-9]+(?![0-9a-z]))",
            "end": "(?:x(?<!x))",
            "beginCaptures": {
                "1": {"name": "variable"},
                "2": {"name": "constant.other"},
                "3": {"name": "constant.numeric"}
            },
            "patterns": [{"include": "#C8"}]
        },
        "iffElse,iff": {
            "begin": "(if)(?=\\%\\%[^\\n]*$|[\\t-\\n\\r ]|\\%|\\()",
            "end": "\\)",
            "beginCaptures": {"1": {"name": "keyword"}},
            "patterns": [{"include": "#C0"}]
        },
        "S2": {
            "begin": "(\\\")",
            "end": "(\\\")",
            "beginCaptures": {"1": {"name": "string.template"}},
            "endCaptures": {"1": {"name": "string.template"}},
            "patterns": [{"include": "#C11"}],
            "contentName": "string.template"
        }
    },
    "foldingEnd": "\\)",
    "foldingStart": "\\(",
    "firstLineMatch": ""
}
```
</details>

A more extensive grammar that also is converted perfectly is provided in [`src/main/rascal/testing/automated/experiments/simpleRealistic`](src/main/rascal/testing/automated/experiments/simpleRealistic/SimpleRealisticExperiment). 

## Terminology fixes

While writing the report, some terms were changed to be more appropriate. These have not all been updated in the code, and should be fixed eventually. For now, the following table can be referenced:

| Code                                  | Report                                                           |
|---------------------------------------|------------------------------------------------------------------|
| ConvSymbol                            | ProdComp (Production Component)                                  |
| PSNFA                                 | TCNFA (Tagged Contextualized Non-deterministic Finite Automaton) |
| Scopes/ScopeList                      | Scope/CategoryList                                               |
| Scope/Token                           | Category/TermCategory                                            |
| Modifier                              | Constraint                                                       |
| RightRecursive (in prefix conversion) | LeftRecursive                                                    |
