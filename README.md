# syntax-highlighter
Code for generating syntax highlighters from context free grammars

<!-- Reference to the semantic tokenizer: https://github.com/usethesource/rascal-language-servers/blob/52eb86d1b7c83a131816d3e6c9484fee80fe48e2/rascal-lsp/src/main/java/org/rascalmpl/vscode/lsp/util/SemanticTokenizer.java -->

Short-term todo:
- [x] Add sol and eol regex support (relatively common to have eol for comments)
- [ ] Add dynamic symbol expansion to deal with non-determinism in certain cases
- [ ] Deal with grammar structure assumptions after regex conversion:
    - [ ] Modifiers (lookarounds/etc) not being resolved in the grammar after regex conversion
    - [ ] Every production should start with a regular expression
- [ ] Add alternatives common prefix check for determinism (to deal with if/else statements)

