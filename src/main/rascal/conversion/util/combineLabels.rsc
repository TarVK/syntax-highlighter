module conversion::util::combineLabels

import ParseTree;
import String;

import conversion::conversionGrammar::ConversionGrammar;
import util::List;

@doc {
    Copies all labels from the given sources onto the target symbol
}
Symbol combineLabels(Symbol target, set[Symbol] labelSources) {
    labelsSet = {*split(",", name) | label(name, _) <- labelSources};
    labels = [name | name <- labelsSet];
    plainTarget = getWithoutLabel(target);
    return size(labels)>0 ? label(stringify(labels, ","), plainTarget) : plainTarget;
}