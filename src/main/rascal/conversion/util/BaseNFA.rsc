module conversion::util::BaseNFA

import regex::PSNFA;
import regex::regexToPSNFA;
import regex::RegexTypes;

public NFA[State] emptyNFA = regexToPSNFA(Regex::empty());
public NFA[State] neverNFA = regexToPSNFA(never());