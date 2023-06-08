module regex::RegexSyntax

syntax RegexCST 
    = char: RawChar
    | charClass: ChararacterClass
    | never: "$0"
    | empty: "$e"
    | always: "$1"
    | multiIteration: RegexCST "+"
    | iteration: RegexCST "*"
    | minIteration: RegexCST "{" Num min "," "}"
    | maxIteration: RegexCST "{" "," Num max "}"
    | minMaxIteration: RegexCST "{" Num min "," Num max "}"
    | exactIteration: RegexCST "{" Num amount "}"
    | optional: RegexCST "?"
    > right concatenation: RegexCST head !>> [\-!\>\<] [\-!\>\<] !<< RegexCST tail
    > left (
        left lookahead: RegexCST exp "\>" RegexCST lookahead
        | left emptyLookahead: "\>" RegexCST lookahead
        | left negativeLookahead: RegexCST exp "!\>" RegexCST negativeLookahead
        | left emptyNegativeLookahead: "!\>" RegexCST negativeLookahead
        | right lookbehind: RegexCST lookbehind "\<" RegexCST exp
        | right emptyLookbehind: RegexCST lookbehind "\<"
        | right negativeLookbehind: RegexCST negativeLookbehind "!\<" RegexCST exp
        | right emptyNegativeLookbehind: RegexCST negativeLookbehind "!\<"
    )
    > left alternation: RegexCST opt1 "|" RegexCST opt2
    > left subtract: RegexCST "-" RegexCST 
    > left emptySubtract: "-" RegexCST 
    | bracket \bracket: "(" RegexCST ")";

syntax ChararacterClass
	= simpleCharclass: "[" Range* ranges "]" 
	| complement: "!" ChararacterClass 
	> left difference: ChararacterClass lhs "--" ChararacterClass rhs 
	> left intersection: ChararacterClass lhs "&&" ChararacterClass rhs 
	> left union: ChararacterClass lhs "||" ChararacterClass rhs 
	| bracket \bracket: "{" ChararacterClass charClass "}" ;
 
syntax Range
	= fromTo: Char start "-" Char end 
	| character: Char character;

syntax Num = [0-9]+;

lexical Char
	= "\\" [\[\]\-bfnrt] 
	| ![\[\]\-];
lexical RawChar = ![(){}\[\]\<\>,\-+*!|&?$];