module regex::RegexSyntax

syntax RegexCST 
    = charCST: RawChar
    | charClassCST: ChararacterClass
    | neverCST: "$0"
    | emptyCST: "$e"
    | alwaysCST: "$1"
    | EOL: "$$"
    | SOL: "^"
    > multiIterationCST: RegexCST "+"
    | iterationCST: RegexCST "*"
    | minIterationCST: RegexCST "{" Num min "," "}"
    | maxIterationCST: RegexCST "{" "," Num max "}"
    | minMaxIterationCST: RegexCST "{" Num min "," Num max "}"
    | exactIterationCST: RegexCST "{" Num amount "}"
    | optionalCST: RegexCST "?"
    > right concatenationCST: RegexCST head !>> [\\!\>\<] [\\!\>\<] !<< RegexCST tail
    > left alternationCST: RegexCST opt1 "|" RegexCST opt2
    > right subtractCST: RegexCST "\\" RegexCST 
    > emptySubtractCST: "\\" RegexCST 
    > right (
        lookaheadCST: RegexCST exp "\>" RegexCST lookahead
        | emptyLookaheadCST: "\>" RegexCST lookahead
        | negativeLookaheadCST: RegexCST exp "!\>" RegexCST negativeLookahead
        | emptyNegativeLookaheadCST: "!\>" RegexCST negativeLookahead
    )
    > left (
        lookbehindCST: RegexCST lookbehind "\<" RegexCST exp
        | emptyLookbehindCST: RegexCST lookbehind "\<"
        | negativeLookbehindCST: RegexCST negativeLookbehind "!\<" RegexCST exp
        | emptyNegativeLookbehindCST: RegexCST negativeLookbehind "!\<"
    )
    | bracket \bracketCST: "(" RegexCST ")"
    | bracket \scopedCST: "(""\<"ScopesCST"\>" RegexCST ")";

syntax ChararacterClass
	= anyCharCST: "."
    | simpleCharclassCST: "[" RangeCST* ranges "]" 
	| complementCST: "!" ChararacterClass 
	> left differenceCST: ChararacterClass lhs "-" ChararacterClass rhs 
	> left intersectionCST: ChararacterClass lhs "&&" ChararacterClass rhs 
	> left unionCST: ChararacterClass lhs "||" ChararacterClass rhs 
	| bracket \bracketCST: "{" ChararacterClass charClass "}" ;
 
syntax RangeCST
	= fromToCST: Char start "-" Char end 
	| characterCST: Char character;

syntax ScopesCST = {ScopeCST ","}+;
syntax ScopeCST = {TokenCST "."}+;
syntax TokenCST = RawChar+;

syntax Num = [0-9]+;

lexical Char
	= "\\" [\\\[\]\-bfnrt] 
	| ![\\\[\]\-];
lexical RawChar = ![(){}\[\]\<\>,\-+*!|&?$^.\\];