module specTransformations::addWordBorders

import Grammar;
import String;
import IO;

import regex::util::charClass;

@doc {
    Transforms the grammar to add negative lookaheads and behinds to words to force whitespace between two keywords. This disallows certain sentences from the language, and thus modifies the language (I.e. the spec) itself. 

    The detectionCharacters class is used to detect whether negative lookarounds should be added, lookaroundCharacters is used as the negative lookarounds
}
Grammar addWordBorders(Grammar grammar, CharClass characters) 
    = addWordBorders(grammar, characters, characters);
Grammar addWordBorders(Grammar grammar, CharClass detectionCharacters, CharClass lookaroundCharacters) {
    bool overlapsChar(CharClass otherChars)
        = fIntersection(detectionCharacters, otherChars) != [];
    
    lookaroundSym = \char-class(lookaroundCharacters);

    upperCaseOffset = 65 - 97; // A - a
    CharClass withUpperCase(int char) 
        =  97 <= char && char <= 122 // a <= char <= z
            ? [range(char+upperCaseOffset, char+upperCaseOffset), range(char, char)]
            : [range(char, char)];

    grammar.rules = (
        sym:  top-down-break visit(grammar.rules[sym]) {
            case s:\lit(text): {
                set[Condition] conditions = {};

                firstChar = charAt(text, 0);
                if(overlapsChar([range(firstChar, firstChar)]))
                    conditions += \not-precede(lookaroundSym);

                lastChar = charAt(text, size(text)-1);
                if(overlapsChar([range(lastChar, lastChar)]))
                    conditions += \not-follow(lookaroundSym);
                    
                if(conditions != {}) insert \conditional(s, conditions);
                else                 insert s;
            }
            case s:\cilit(text): {
                set[Condition] conditions = {};

                firstChar = charAt(text, 0);
                if(overlapsChar(withUpperCase(firstChar)))
                    conditions += \not-precede(lookaroundSym);

                lastChar = charAt(text, size(text)-1);
                if(overlapsChar(withUpperCase(lastChar)))
                    conditions += \not-follow(lookaroundSym);
                    
                if(conditions != {}) insert \conditional(s, conditions);
                else                 insert s;
            }
            // Don't recurse into conditionals (note top-down-*break*)
            case s:\conditional(_, _) => s
            // Don't recurse into keyword productions
            case s: prod(sym, _, _) => s when /keywords(_) := sym
        }
        | sym <- grammar.rules
    );

    return grammar;
}