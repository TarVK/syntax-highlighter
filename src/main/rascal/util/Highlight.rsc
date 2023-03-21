module util::Highlight

import lang::html::IO;
import measures::util::Tokenization;
import util::Sampling;
import util::IDEServices;
import Content;
import IO;
import String;

Content showHighlight(Tokenization tokenization, HTMLElement highlightStyle = baseHighlightStyle) 
    = content(md5Hash(tokenization), tokenizationServer(tokenization, highlightStyle));
    
Response (Request) tokenizationServer(Tokenization tokenization, HTMLElement highlightStyle) {
    default Response reply(get(_)) {
        return response(writeHTMLString(span([
            toHTML(tokenization),
            highlightStyle
        ])));
    }

    return reply;
}

HTMLElement toHTML(Tokenization tokenization) = span([toHTML(tokenized) | tokenized <- tokenization]);
HTMLElement toHTML(characterTokens(character, tokens)) = span(
    [toHTML(stringChar(character))], 
    class=("" | it + " " + t | t <- [*split(".", p) | p <- tokens]));


HTMLElement toHTML("\n") = br();
HTMLElement toHTML(str character) = text(character);

HTMLElement baseHighlightStyle = style([text("
    body {
        color: white;
        background-color: #272822;
        font-family: consolas;
    }
    .keyword {color: #eb2672;}
    .comment {color: #88846f;}
    .parameter {color: #fd971f;}
    .function {color: #a6e22e;}
    .symbol {color: #BBBBBB;}
")]);