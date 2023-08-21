module conversion::util::combineLabels

import ParseTree;

import conversion::conversionGrammar::ConversionGrammar;
import util::List;

@doc {
    Copies all labels from the given sources onto the target symbol
}
Symbol combineLabels(Symbol target, set[Symbol] labelSources) {
    labels = [name | label(name, _) <- labelSources];
    plainTarget = getWithoutLabel(target);
    return size(labels)>0 ? label(stringify(labels, ","), plainTarget) : plainTarget;
}