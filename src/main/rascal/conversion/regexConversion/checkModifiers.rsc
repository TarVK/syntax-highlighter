module conversion::regexConversion::checkModifiers

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import Warning;


@doc {
    Modifiers may only be applied to regular expressions in the end. This function creates warnings for all modifiers that haven't been pushed to a regular expression.
}
WithWarnings[ConversionGrammar] checkModifiers(ConversionGrammar grammar) {
    list[Warning] warnings = [];

    ConvSymbol add(ConvSymbol modifier, ConvProd production) {
        warnings += unresolvedModifier(modifier, production);

        return visit (modifier) {
            case m:delete(r, _) => r
            case m:follow(r, _) => r
            case m:notFollow(r, _) => r
            case m:precede(r, _) => r
            case m:notPrecede(r, _) => r
            case m:atEndOfLine(r) => r
            case m:atStartOfLine(r) => r
        };
    }

    newProds = {
        <def, convProd(lDef, 
            top-down-break visit (parts) {
                case m:delete(_, _) => add(m, prod)
                case m:follow(_, _) => add(m, prod)
                case m:notFollow(_, _) => add(m, prod)
                case m:precede(_, _) => add(m, prod)
                case m:notPrecede(_, _) => add(m, prod)
                case m:atEndOfLine(_) => add(m, prod)
                case m:atStartOfLine(_) => add(m, prod)
            }
        )>
        | <def, prod:convProd(lDef, parts)> <- grammar.productions
    };

    return <warnings, convGrammar(grammar.\start, newProds)>;
}