module mapping::intermediate::scopeGrammar::toScopeGrammar

import util::Maybe;

import mapping::common::stringifyOnigurumaRegex;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import conversion::util::meta::extractSources;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::intermediate::scopeGrammar::cleanupRegex;
import mapping::intermediate::scopeGrammar::extractRegexScopes;
import mapping::intermediate::scopeGrammar::removeRegexSubtraction;
import mapping::intermediate::scopeGrammar::splitRegexLookarounds;
import regex::RegexCache;
import regex::regexToPSNFA;
import regex::Regex;
import regex::PSNFA;
import regex::PSNFATypes;
import regex::PSNFATools;
import regex::NFASimplification;
import regex::PSNFACombinators;
import conversion::util::makeLookahead;
import Warning;
import Logging;
import Scope;

@doc {
    Converts a conversion grammar to a scope grammar. 
    Assumes that every production in the conversion grammar has the correct format, meaning that every production must have one of the following shapes:
    ```
    A -> 
    A -> X A
    A -> X B Y A
    ```
}
WithWarnings[ScopeGrammar] toScopeGrammar(ConversionGrammar grammar, Logger log) {
    log(Section(), "to scope grammar");

    Context context = <
        [], // list[Warning] warnings,
        (), // TokenCache tokenCache,
        (), // ScopeCache scopeCache, 
        (), // RegexConversionCache regexConversionCache,
        (), // ScopeProductions scopeProductions, 
        (), // SymbolMap symbolMap,
        {}, // set[str] takenSymbols,
        log //Logger log
    >;

    for(sym <- grammar.productions<0>) {
        symInpProds = grammar.productions[sym];
        <textSym, context> = getSymbolString(sym, context);
        log(Progress(), "defining <textSym>");

        list[ScopeProd] symProds = [];
        context.scopeProductions[textSym] = symProds;

        for(prod:convProd(_, [regexp(r), ref(_, _, _)]) <- symInpProds) {
            <prodSym, context> = defineTokenProd(r, prod, context);
            symProds += inclusion(prodSym);
        }

        for(prod:convProd(_, [regexp(open), ref(refSym, scopes, _), regexp(close), ref(_, _, _)]) <- symInpProds) {
            <textRef, context> = getSymbolString(refSym, context);
            <prodSym, context> = defineScopeProd(open, textRef, scopes, close, prod, context);
            symProds += inclusion(prodSym);
        }

        context.scopeProductions[textSym] = symProds;
    }


    return <context.warnings, scopeGrammar(getSymbolString(grammar.\start, context)<0>, context.scopeProductions)>;
}

/* Define some data and caches to prevent performing the same work multiple times */
alias Context = tuple[
    list[Warning] warnings,

    TokenCache tokenCache,
    ScopeCache scopeCache, 
    RegexConversionCache regexConversionCache,
    
    ScopeProductions scopeProductions, 

    SymbolMap symbolMap,
    set[str] takenSymbols,

    Logger log
];
alias SymbolMap = map[Symbol, str];
alias TokenCache = map[NFA[State], str];
alias ScopeCache = map[tuple[NFA[State], str, ScopeList, NFA[State]], str];
alias RegexConversionCache = map[NFA[State], tuple[Regex, list[Scope]]];


@doc {
    Defines the entry for the given token production into the context, and returns the label to refer to it
}
tuple[
    str, 
    Context
] defineTokenProd(
    Regex regex, 
    ConvProd prod,
    Context context
) {
    key = regexToPSNFA(regex);
    if(key in context.tokenCache) return <context.tokenCache[key], context>;

    <textSym, context> = createUniqueID(just(text) := getLabel(prod) ? text : "T", context);
    context.tokenCache[key] = textSym;

    <scopedRegex, context> = convertRegex(regex, prod, context);
    context.scopeProductions[textSym] = [tokenProd(scopedRegex, sources=extractSources(prod.parts))];

    return <textSym, context>;
}

@doc {
    Defines the entry for the given scope production into the context, and returns the label to refer to it
}
tuple[
    str, 
    Context
] defineScopeProd(
    Regex open, 
    str ref,
    ScopeList scopes,
    Regex close,
    ConvProd prod,
    Context context
) {
    key = <regexToPSNFA(open), ref, scopes, regexToPSNFA(close)>;
    if(key in context.scopeCache) return <context.scopeCache[key], context>;

    <textSym, context> = createUniqueID(just(text) := getLabel(prod) ? text : "S", context);
    context.scopeCache[key] = textSym;

    Scope scope;
    if([first, second, *rest] := scopes) {
        // If we want a secuence of scopes, we simply use lookaheads to open a sequence of symbols
        scope = first;
        <ref, context> = defineScopeProd(
            open, 
            ref, 
            [second, *rest], 
            makeLookahead(close, false), 
            prod, 
            context
        );
        open = makeLookahead(open, false);
    } else if([first] := scopes) 
        scope = first;
    else if([] := scopes)
        scope = "";

    <openScoped, context> = convertRegex(open, prod, context);
    <closeScoped, context> = convertRegex(close, prod, context);
    context.scopeProductions[textSym] = [scopeProd(openScoped, <ref, scope>, closeScoped, sources=extractSources(prod.parts))];

    return <textSym, context>;
}



@doc {
    Converts a given regular expression with embedded scopes into a format with captures groups and corresponding scopes. 
}
tuple[
    tuple[Regex, list[Scope]],
    Context
] convertRegex(Regex regex, ConvProd prod, Context context) {
    key = regexToPSNFA(regex);
    regex = removeMeta(regex);
    if(key in context.regexConversionCache) 
        return <context.regexConversionCache[key], context>;

    <subtractionlessRegex, isEqual> = removeRegexSubtraction(regex);
    if(!isEqual) {
        delta = differencePSNFA(regexToPSNFA(regex), regexToPSNFA(subtractionlessRegex));
        minimizedDelta = minimizeUnique(delta);
        context.warnings += [unresolvableSubtraction(regex, minimizedDelta, prod)];
    }

    emptyLookarounds = splitRegexLookarounds(removeMeta(subtractionlessRegex));
    improvedRegex = cleanupRegex(emptyLookarounds);
    result = extractRegexScopes(improvedRegex);
    
    if(subtractionlessRegex != regex) {
        rt = stringifyOnigurumaRegex(improvedRegex);
        if(isEqual) context.log(ProgressDetailed(), "safely removed subtraction from regex: <rt>");
        else        context.log(ProgressDetailed(), "removed subtraction from regex with errors: <rt>");
    }

    context.regexConversionCache[key] = result;
    return <result, context>;
}

@doc {
    Creates a unique string (id), trying to use the given name.
    Requires a set of taken ids to be specified, and outputs the updated set. 
}
tuple[str name, Context context] createUniqueID(str name, Context context) {
    if(name in context.takenSymbols) {
        int i = 1;
        while("<name><i>" in context.takenSymbols) i+=1;
        name = "<name><i>";
    }

    context.takenSymbols += {name};
    return <name, context>;
}

@doc {
    Converts a given symbol into a string representing this symbol.
    This is stored in the symbol map for later used, and in the textSymbols for quick lookup of whether a string is still available. 
}
tuple[str name, Context context] getSymbolString(
    Symbol sym, 
    Context context
) {
    sym = getWithoutLabel(sym);
    if(sym in context.symbolMap) return <context.symbolMap[sym], context>;

    str text = "G";
    switch(sym) {
        case sort(t): text = t;
        case lex(t): text = "L<t>";
        case layouts(t): text = "W<t>";
        case keywords(t): text = "K<t>";
    }

    <labelText, context> = createUniqueID(text, context);
    context.symbolMap[sym] = labelText;
    return <labelText, context>;
}