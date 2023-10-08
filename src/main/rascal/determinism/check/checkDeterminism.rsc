module determinism::check::checkDeterminism

import conversion::conversionGrammar::ConversionGrammar;
import determinism::check::checkAmbiguity;
import determinism::check::checkClosingExpressionOverlap;
import determinism::check::checkExtensionOverlap;
import Logging;
import Warning;

@doc {
    Checks whether the output grammar is deterministic.

    Assumes that every production in the conversion grammar has the correct format, meaning that every production must have one of the following shapes:
    ```
    A -> 
    A -> X A
    A -> X B Y A
    ```
    Also assumes that there's no overlap between alternatives of a given symbol.
}
list[Warning] checkDeterminism(ConversionGrammar grammar, Logger log) {
    log(Section(), "checking determinism");
    log(Progress(), "checking ambiguity");
    aWarnings = checkAmbiguity(grammar);
    log(Progress(), "checking closing overlap");
    cWarnings = checkClosingExpressionOverlap(grammar);
    log(Progress(), "checking extension overlap");
    eWarnings = checkExtensionOverlap(grammar);
    return aWarnings + cWarnings + eWarnings;
}