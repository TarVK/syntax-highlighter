module transformations::util::GetBaseDependency

import Type;

// Retrieves the core reference of a symbol, I.e. stripping all labels (and in future possible other data)
Symbol getBaseDependency(Symbol sym) = visit(sym) {
    case label(_, prod) => prod
};