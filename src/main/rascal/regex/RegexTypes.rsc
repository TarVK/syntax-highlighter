module regex::RegexTypes

import ParseTree;

import regex::Tags;
import Scope;

data Regex = never()
           | empty()
           | always()
           | character(list[CharRange] ranges)
           | lookahead(Regex r, Regex lookahead)
           | lookbehind(Regex r, Regex lookbehind)
           | \negative-lookahead(Regex r, Regex lookahead)
           | \negative-lookbehind(Regex r, Regex lookbehind)
           | concatenation(Regex head, Regex tail)
           | alternation(Regex opt1, Regex opt2)
           | \multi-iteration(Regex r) // 1 or more
           | subtract(Regex r, Regex removal)
           | mark(Tags tags, Regex r)
           // Additional extended syntax, translatable into the core
           | eol()
           | sol()
           | concatenation(list[Regex] parts)
           | alternation(list[Regex] options)
           | iteration(Regex r) // 0 ore more
           | optional(Regex r)
           | \exact-iteration(Regex r, int amount)
           | \min-iteration(Regex r, int min)
           | \max-iteration(Regex r, int max)
           | \min-max-iteration(Regex r, int min, int max);
data ScopeTag = scopeTag(Scopes scopes);