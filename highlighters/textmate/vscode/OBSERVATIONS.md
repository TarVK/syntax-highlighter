# Observations

-   Empty rules with patterns can be defined that always match: `{"patterns": [...]}`
-   An empty end capture: "" can be used to never end a group
-   Deals well with super deep nestings in terms of performance
-   Only the top scope "end" match is active
    -   Can use a lookahead of parent to break out of multiple scopes at once
-   If both "end" matches and a pattern in the scope matches, "end" gets priority:

    -   Can use a negative lookahead of the conjunction of all sub-patterns as the "end" match in order to exit when no more children match

-   Textmate 2 supports patterns within capture statements:
    <details>
    <summary>Example</summary>

    ```js
    { patterns = (
        {
            name = 'markup.bold.toy';
            match = '\*.*?\*';
            captures = {
                0 = {
                    patterns = ({
                        name = 'markup.italic.toy';
                        match = '_.*?_';
                    });
                };
            };
        }, {
            name = 'markup.italic.toy';
            match = '_.*?_';
            captures = {
                0 = {
                    patterns = ({
                        name = 'markup.bold.toy';
                        match = '\*.*?\*';
                    });
                };
            };
        }
    ); }
    ```

    Source: https://www.apeth.com/nonblog/stories/textmatebundle.html
    </details>

-   Grammars can deal with "non-determinism" by means of declaration ordering, and lookahead and behind groups
-   TM's regex allows for back-references, making this aspect more powerful than CFGs. Hence expressivity is incomparable with CFGs
-   TM allows usage of capture group matches within the scope
-   Different parts of the same regex can be labeled differently using `captures`
