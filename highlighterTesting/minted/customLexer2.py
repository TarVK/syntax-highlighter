# -*- coding: utf-8 -*-
"""
    pygments.lexers.imagej_macro
    ~~~~~~~~~~~~~~~~~~~~

    Lexers for ImageJ Macro.

    :copyright: Copyright 2006-2017 by the Pygments team, see AUTHORS.
    :license: BSD, see LICENSE for details.
"""

import re

from pygments.lexer import Lexer, include, bygroups, default, using, this, words, combined
from pygments.token import Text, Comment, Token, Operator, Keyword, Name, String, Number, Punctuation, Other, Whitespace, Generic, Error, string_to_tokentype
from pygments.styles import STYLE_MAP
from pygments.style import Style
from pygments.filter import apply_filters, Filter
import os
import json

tokenPath = "./data/input.tokens.json";
tokens = json.loads(open(tokenPath).read());
textPath = "./data/input.txt";
text = open(textPath).read();

__all__ = ['CustomLexer'];

def mapToken(token): 
    return string_to_tokentype(".".join([token.capitalize() for token in token.split(".")]));

# Token.Literal.Number.Bin == "Token.Literal.Number.Bin";
class CustomLexer(Lexer):
    def get_tokens(self, skippedText, unfiltered=False):
        prevToken = None;
        prevIndex = 0;
        index = 0;
        for scope in tokens:
            tokenText = ".".join(scope);
            token = mapToken(tokenText);
            if(token != prevToken):
                if(prevToken != None):
                    yield (prevToken, text[prevIndex:index])
                prevToken = token;
                prevIndex = index;
            index += 1;
        yield (prevToken, text[prevIndex:index])
        yield (Text, "\n");
