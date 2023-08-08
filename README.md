# syntax-highlighter
Code for generating syntax highlighters from context free grammars

<!-- Reference to the semantic tokenizer: https://github.com/usethesource/rascal-language-servers/blob/52eb86d1b7c83a131816d3e6c9484fee80fe48e2/rascal-lsp/src/main/java/org/rascalmpl/vscode/lsp/util/SemanticTokenizer.java -->

Todo:
- [ ] Broaden symbols
- [ ] Detect nullable loops (E.g. A -> /()|s/ A)
- [ ] Deal with chains of symbols
- [ ] Check determinism/improve determinism
- [ ] Translate conversion grammar to highlight grammar
- [ ] Improve robustness


## Broaden symbols

If for a given non-terminal `A`, all its productions modulo definition name is contained in the set of productions of `B`, we can replace occurrences of `B` by `A`. This is only safe however if it does not cause new non-determinism.

## Dealing with symbol chains

Every production should eventually be of one of these shapes:
- `A -> (<s> X B!)`
- `A -> (<s> X B!) A!`
- `A -> (<s> X B! Y) A!`
- `A -> `

In all of these, `B` may equal `A`.

Any sequence of symbols that doesn't follow this format, should be broken up. There's multiple ways to do this, depending on the exact pattern.

for a sequence `x`, we define `A -> ...x` inductively on `x` as follows:


```
A -> ...()
=
```

```
A -> ...(X y)
=
A -> X A
A -> ...y
```

```
A -> ...(B y)
=
A -> ...B
A -> ...y
```

for a non-terminal `B`, we define `A -> ...B` as a copy of all of `B`'s productions, with the right-most `B`s replaced by `A`:
```
A -> ...B
B -> X B
B -> Y B
B ->
= 
A -> X A
A -> Y A
A ->
```

### `A -> X x Y A`
```
A -> X x Y A
=>
A -> X A' Y A
A' -> ...x
```

### `A -> X x B A`
```
A -> X x B A
=>
A -> X A' A
A' -> ...x
A' -> ...B
```

### `A -> X x A`
```
A -> X x A
=>
A -> X A
A -> ...x
```

## Check determinism 

In order to ensure that the syntax-highlighter correctly highlights according to the given grammar, we have to ensure that everything (other than the internals of the regular expressions) is deterministic. The syntax-highlighter won't backtrack on earlier made choices to improve recognition of later tokens. 

There are 3 situations for which determinism has to be checked:
- Variable length matches:
    - A given regular expression may match a word `ps` for `p,s ∈ Σ`, while also matching just `p` on it's own. In this case the syntax highlighter makes a greedy choice between `p` and `ps`, and this choice may not be the one that leads to the correct parse.
- Alternatives matches:
    - When matching a non-terminal `A`, it chooses one of all possible alternatives of `A`, depending on whether the first regular expression of each of the alternatives matches. Hence only one of the regular expressions of these alternatives may match at a time, or else the syntax highlighter will make a greedy choice which may not be the one that leads to the correct parse.
- Terminal matches:
    - When the syntax highlighter is in a certain "scope", E.g. `B` within the production `A -> X B Y A`, the scope closer `Y` may not match while an alternative of `B` also matches. If it does, the syntax highlighter will choose to close the scope by matching `Y`, while it might have needed to match a rule from `B` first to lead to a correct parse.

Special care has to be taken for productions of the form `A -> (<s> X B!) A!`. Here we have two non-terminals in a row, which means we have to ensure there's no overlap between any of the alternatives of these non-terminals, or else we don't know when to exit it `B`. And we also have to make sure we correctly perform terminal matches against `B` as well, not only against `A`. If `B` has productions of this same shape `B -> (<s> X C!) B!`, these requirements are transitive, hence overlap between alternatives of `C` and `A` and closers for `A` and alternatives of `C` also have to be checked.

## Translate conversion grammar to highlight grammar

When translating the final grammar into a highlighting grammar, we simply have to map every production to an appropriate matching expression supported by the highlighting grammar.

Using several transformations, we can find a reduced hard core of expression shapes we have to support:
- `A -> `
- `A -> X A!`
- `A -> (<s> X B! Y) A!`
where `B` may equal `A`.

### Highlighting grammar translation

#### `A -> `
This production is trivially present in how syntax highlighters function. 

#### `A -> X A!`
This corresponds to a simple rule for `X` in both TM and Monarch.

#### `A -> (<s> X B! Y) A!`
In TM, this rule is very directly translatable into a pattern, using the `begin` and `end` fields for `X` and `Y`, and using `B!` as sub-patterns, and finally using `s` as the name of the overall pattern.

In Monarch this is slightly more effort. `X` would be a rule of `A`, which pushes `B!_Y` onto the stack. `B!_Y` would have all rules of `B!`, as well as a rule for `Y`, which performs a pop from the stack. `s` must be empty in order to support Monarch. 


### Hard-core translation

#### `A -> (<s> X B!)` where `s` is non-empty or `B! != A!`
To support this form of production, in both TM and Monarch we wil have to create dedicated symbol, closing expression pairs for any production that can lead to a production of this shape. E.g. if we have the production `C -> (<s> X A! Y) C!`, it would be transformed to `C -> (<s> X A!_Y Y) C!`, where `A_Y` is the pair of `A` and its closing expression `Y`. Then any production of `A` that does not have this shape can be copied to `A_Y` as it is. For `A_Y -> (<s> X B!)`, we create the production `A_Y -> (<s> X B! (>Y)) A_Y`, where `(>Y)` is the positive lookahead regex of `Y`. This production can then be translated both in TM and Monarch as described earlier.

#### `A -> (<s> X B!) A!`
There are two ways to implement this, both of which are correct, but have slightly different characteristics regarding syntactically incorrect inputs. We can perform a greedy exit, or a lazy exit.

##### Greedy exit
For a greedy exit, we simply take all the first expressions of all alternatives of `B`, and use this as a negative lookahead for `B`. Let `Y_1...Y_k` be the first regular expressions of all alternatives of `B`, then we obtain the following expression: `A -> (<s> X B! (!>(Y_1|...|Y_k))) A!`. This expression specifies that we only exit the scope of `B` once no alternative of `B` matches anymore. This means that anything that does not adhere to the syntax, will also exit. 

##### Lazy exit
For a lazy exit, we consider pairs of non-terminal symbols together with its closing expression, as described in the previous translation. For symbols without a closing expression, we can simply use a never-matching expression and simplify from there. Given the pair `A_Y` with `A_Y -> (<s> X B!) A!_Y`, we consider the first regular expressions `Z_1...Z_k` of all alternatives of `A`. Using this we can obtain the following expression: `A_Y -> (<s> X B! (>(Y|Z_1|...|Z_k))) A!_Y`. This expressions specifies that we exit the scope of `B` once we would either close `A` fully, or match something in `A`. This means that we stay in the scope of `B` when encountering symbols that do not adhere to the syntax.

## Improve robustness/responsiveness
Due to usage of regex, it is possible that styling is only applied once some syntactic structure is fully finished. For instance (depending on the input grammar), a string might not be highlighted as a string until the closing quotation mark is inserted. There are several things we can do to try improve this:

- Try remove (parts of) positive lookaheads, as long as it doesn't cause non-determinism
- Split concatenation regexes when possible:
    ```
    A -> X Y A
    =>
    A -> X A
    A -> Y A
    ```
- Optionalize concatenation regex when possible:
    ```
    A -> X Y A
    =>
    A -> X Y? A
    ```
- Split body concatenation regexes when possible:
    ```
    A -> X Y Z A
    =>
    A -> X A' Z A
    A' -> Y A'
    A' ->
    ```
- Split start/stop concatenations regexes when possible:
    ```
    A -> X Y A' Z A
    =>
    A -> X A' Z A
    A' -> Y A'
    ```
    and
    ```
    A -> X A' Y Z A
    =>
    A -> X A' Z A
    A' -> Y A'
    ```