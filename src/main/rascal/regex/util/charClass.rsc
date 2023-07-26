module regex::util::charClass

import lang::rascal::grammar::definition::Characters;
import lang::rascal::format::Escape;

import ParseTree;
import regex::util::GetDisjointCharClasses;

CharClass anyCharClass() = [range(1,0x10FFFF)];

str stringify(CharClass cc) {
    hasMin = any(range(s, e) <- cc, s <= 1 && 1 <= e);
    hasMax = any(range(s, e) <- cc, s <= 0x10FFFF && 0x10FFFF <= e);
    negate = hasMin && hasMax;
    if (negate) cc = fComplement(cc);

    str chars = "";
    for(range(f, t)<-cc) {
        from = makeCharClassChar(f);
        to = makeCharClassChar(t);
        if(from == to) chars += from;
        else chars += from+"-"+to;
    }
    return negate ? (size(cc)==0 ? "." : "![<chars>]") : "[<chars>]";
}