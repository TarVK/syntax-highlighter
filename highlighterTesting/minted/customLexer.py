# -*- coding: utf-8 -*-
"""
    pygments.lexers.imagej_macro
    ~~~~~~~~~~~~~~~~~~~~

    Lexers for ImageJ Macro.

    :copyright: Copyright 2006-2017 by the Pygments team, see AUTHORS.
    :license: BSD, see LICENSE for details.
"""

import re

from pygments.lexer import RegexLexer, include, bygroups, default, using, this, words, combined
from pygments.token import Text, Comment, Operator, Keyword, Name, String, Number, Punctuation, Other, Whitespace, Generic, Error, string_to_tokentype
from pygments.styles import STYLE_MAP
from pygments.style import Style
import os
import json


grammarPath = "./data/pygmentsGrammar.json";
grammarInput = json.loads(open(grammarPath).read());

__all__ = ['CustomLexer'];

def mapToken(token): 
    return string_to_tokentype(".".join([token.capitalize() for token in token.split(".")]));

def mapRule(rule):
    if "include" in rule: 
        return include(rule["include"]);
    if "push" in rule: 
        return (
            rule["regex"], 
            bygroups(*[mapToken(token) for token in rule["token"]]), 
            rule["push"]
        );
    if "regex" in rule:
        return (
            rule["regex"], 
            bygroups(*[mapToken(token) for token in rule["token"]])
        );
    print("Invalid rule", rule);

# Token.Literal.Number.Bin == "Token.Literal.Number.Bin";
class CustomLexer(RegexLexer):
    flags = re.DOTALL | re.UNICODE | re.MULTILINE;

    tokens = {
        state: [mapRule(ruleInp) for ruleInp in grammarInput[state]] 
        for state in grammarInput
    };