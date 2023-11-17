module testing::util::checkAliases

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import conversion::util::Alias;

@doc {
    Checks whether the given grammar has invalid aliases (self-recursive)
    throws an error if such aliases are detected
}
void checkAliases(ConversionGrammar grammar) {
    syms = grammar.productions<0>;
    for(sym <- syms) {
        if(isAlias(sym, grammar)) {
            aliasSym = sym;
            set[Symbol] found = {aliasSym};
            while({convProd(_, [ref(refSym, _, _)])} := grammar.productions[aliasSym]) {
                aliasSym = getWithoutLabel(refSym);
                if(aliasSym in found) throw sym;
            }
        }
    }
}