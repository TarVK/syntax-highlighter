module conversion::util::meta::RegexSources

import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;

@doc {
    Extracts the regex sources that apply to the entire regular expression
}
tuple[set[SourceProd], Regex] extractRegexSources(Regex regex) {
    switch(regex) {
        case meta(r, value m): {
            <recSources, recR> = extractRegexSources(r);
            if(set[SourceProd] sources := m)
                return <recSources + sources, recR>;
            return <recSources, meta(recR, m)>;
        }
        case mark(tags, r): {
            <recSources, recR> = extractRegexSources(r);
            return <recSources, mark(tags, recR)>;
        }
        case \multi-iteration(r): {
            <recSources, recR> = extractRegexSources(r);
            return <recSources, \multi-iteration(recR)>;
        }
        case iteration(r): {
            <recSources, recR> = extractRegexSources(r);
            return <recSources, iteration(recR)>;
        }
        case optional(r): {
            <recSources, recR> = extractRegexSources(r);
            return <recSources, optional(recR)>;
        }
        // TODO: consider also extracting sources that are shared between multiple branching paths:
        // case lookahead(r, la): {
        //     <recSourcesR, recR> = extractRegexSources(r);
        //     <recSourcesLA, recLa> = extractRegexSources(la);
        //     sharedSources = recSourcesR & recSourcesLA;

        //     remainingSourcesR = recSourcesR - sharedSources;
        //     if(size(remainingSourcesR)>0) recR = meta(recR, remainingSourcesR);

        //     remainingSourcesLA = recSourcesLA - sharedSources;
        //     if(size(remainingSourcesLA)>0) recLA = meta(recLA, remainingSourcesR);

        //     return <sharedSources, lookahead(recR, recLA)>;
        // }
        default: return <{}, regex>;
    }
}

@doc {
    Adds the specified sources to the given regular epxression
}
Regex addRegexSources(Regex regex, set[SourceProd] sources) {
    if(sources == {}) return regex;
    <currentSources, woSources> = extractRegexSources(regex);

    Regex addRec(Regex regex) {
        switch(regex) {
            case mark(tags, r): return mark(tags, addRec(r));
            case meta(r, value m): {
                if(set[SourceProd] sources !:= m)
                    return meta(addRec(r), m);
            }
        }

        return meta(regex, currentSources + sources);
    }
    return addRec(woSources);
}