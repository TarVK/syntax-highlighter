module conversion::util::meta::LabelTools

import IO;
import ParseTree;
import String;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import util::List;

@doc {
    Copies all labels from the given sources onto the target symbol
}
Symbol combineLabels(Symbol target, set[Symbol] labelSources)
    = relabelSymbol(target, {name | label(name, _) <- labelSources});
Symbol relabelSymbol(Symbol target, set[str] labels) {
    labelsSet = {*split(",", name) | name <- labels};
    labels = [name | name <- labelsSet];
    plainTarget = getWithoutLabel(target);
    return labels == [] ? plainTarget : label(stringify(labels, ","), plainTarget);
}

@doc {
    Retrieve the raw definition symbol, by getting rid of any potential labels
}
Symbol getWithoutLabel(label(_, sym)) = sym;
default Symbol getWithoutLabel(Symbol sym) = sym;

@doc {
    Retrieves the label associated to the production
}
Maybe[str] getLabel(convProd(label(text, _), _)) = just(text);
default Maybe[str] getLabel(ConvProd prod) = nothing();

@doc {
    Keep the label from the first symbol if present, but use the rest of the second symbol
}
Symbol copyLabel(Symbol withLabel, Symbol target) {
    if(label(x, _) := withLabel) return label(x, getWithoutLabel(target));
    return target;
}