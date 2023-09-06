# Production shapes

I discovered that using empty lookaheads, more complex production shapes can be matched using regular expressions.

## Inspiration/test

```
STMT -> if(#EXP){#STMT}else{#STMT}
```
=>
```
STMT -> (>if\() STMT_2 \} STMT
STMT_2 -> \{ STMT_2 \} STMT_2
STMT_2 -> (>if\() STMT_3 else STMT_2
STMT_2 -> 
STMT_3 -> (>else) STMT_3                    // Redundant
STMT_3 -> (>if\() STMT_4 \} STMT_3
STMT_3 -> 
STMT_4 -> \{ EXP (>\}) STMT_4
STMT_4 -> if\( EXP \) STMT_4
STMT_4 -> 
```

This can be tested on the following code in order to see how `else` is only highlighted if used after `if`:
```js
if(something) { 
    else {

    if(okay) else {

    }

    if (smth) while {} else while { while }
    while
} else {
    else {

    if (smth) {} else {}

    while
} else {
    while
}
```

## Technique 1
A production `A -> X_1 B_1 X_2 B_2 ... X_k B_k X_{k+1} A` can be simulated accurately if:
- `X_1` does not overlap with any `X_i` for `i ∈ [2..k]`
- `X_1` does not overlap with any `B_i` for `i ∈ [1..k]`
- `A != B_i` for all `i ∈ [1..k]`
- `X_{i+1}` does not overlap any production of `B_i`, for any `i ∈ [1..k]`

We translate this rule to:
```
A -> (>X_1) A_1 X_{k+1} A
A_1 -> (>X_1) A_2 X_k A_1
A_1 -> ...B_k
A_1 -> 
A_2 -> (>X_1) A_3 X_{k-1} A_2
A_2 -> ...B_{k-1}
A_2 -> 
...
A_k -> X_1 A_k
A_k -> ...B_1
A_k -> 
```

### Applied if/else example

```
STMT -> if( EXP ){ STMT }else{ STMT }
```
=>
```
STMT -> (>if\() STMT_2 \} STMT
STMT_2 -> (>if\() STMT_3 \}else\{ STMT_2
STMT_2 -> ...STMT
STMT_2 -> 
STMT_3 -> (>if\() STMT_4 \)\{ STMT_3
STMT_3 -> ...STMT
STMT_3 -> 
STMT_4 -> if\( STMT_4
STMT_4 -> ...EXP
```

### Observed drawback
the `if` lookahead can be matched from any nested non-terminal (EXP, STMT). Here the `if` lookahead of in STMT_2 can interfere with the copied `if` lookahead of `STMT`. This also explains our `A != B_i` condition, which is not met here.

## Technique 2
A production `A -> X_1 B_1 X_2 B_2 ... X_k B_k X_{k+1} A` can be simulated accurately if:
- `X_1` does not overlap with any `X_i` for `i ∈ [2..k]`
- `X_{i+1}` does not overlap any production of `B_i`, for any `i ∈ [1..k]`
- `X_i` should not overlap `X_i+1` for any `i ∈ [1..k]`

We translate this rule to:
```
A -> (>X_1) A_1 X_{k+1} A
A_1 -> (>X_1) A_2 (>X_k) A_1
A_1 -> X_k B_k (>X_{k+1}) A_1
A_1 -> 
A_2 -> (>X_1) A_3 (>X_{k-1}) A_2
A_2 -> X_{k-1} B_{k-1} (>X_k) A_2
A_2 -> 
...
A_k -> X_1 B_1 (>X_2) A_k
A_k -> 
```

### Applied if/else example

```
STMT -> if( EXP ){ STMT }else{ STMT }
```
=>
```
STMT -> (>if\() STMT_2 \} STMT
STMT_2 -> (>if\() STMT_3 (>\}else\{) STMT_2
STMT_2 -> \}else\{ STMT (>\}) STMT_2
STMT_2 -> 
STMT_3 -> (>if\() STMT_4 (>\)\{) STMT_3
STMT_3 -> \)\{ STMT (>\}else\{) STMT_3
STMT_3 -> 
STMT_4 -> if\( EXP (>\)\{) STMT_4
```

### Observed drawback

It's not unlikely that there's going to be overlap between consecutive `X_i` expressions, such as the case with `}else{` and `}` here. 

### extra benefit
It's relatively trivial how to try improve responsive/robustness with this pattern. In this example
we can replace `STMT_2 -> \}else\{ STMT (>\}) STMT_2` by 
```
STMT_2 -> \{ STMT (>\}) STMT_2
STMT_2 -> \}else STMT_2
```
and replace the `\}else\{` lookaheads with `\}else` lookaheads. This way we now also allow for unfamiliar/wrong characters between the `else` and `{` bracket. Of course we still would have to test this causes no non-determinism. 

## Technique 3
A production `A -> X_1 B_1 X_2 B_2 ... X_k B_k X_{k+1} A` can be simulated accurately if:
- `X_1` does not overlap with any `X_i` for `i ∈ [2..k]`
- `X_1` does not overlap with any production of `B_i`, for any `i ∈ [1..k]`
- `X_{i+1}` does not overlap any production of `B_i`, for any `i ∈ [1..k]`

We translate this rule to:
```
A -> (>X_1) A_1 X_{k+1} A
A_1 -> (>X_1) A_2 X_k A_1
A_1 -> (!>X_1) B_k (>X_{k+1}) A_1
A_1 -> 
A_2 -> (>X_1) A_3 X_{k-1} A_2
A_2 -> (!>X_1) B_{k-1} (>X_k) A_2
A_2 -> 
...
A_k -> X_1 A_k
A_k -> (!>X_1) B_1 (>X_2) A_k
A_k -> 
```

### Applied if/else example

```
STMT -> if( EXP ){ STMT }else{ STMT }
```
=>
```
STMT -> (>if\() STMT_2 \} STMT
STMT_2 -> (>if\() STMT_3 \}else\{ STMT_2
STMT_2 -> (!>if\() STMT (>\}) STMT_2
STMT_2 -> 
STMT_3 -> (>if\() STMT_4 \)\{ STMT_3
STMT_3 -> (!>if\() STMT (>\}else\{) STMT_3
STMT_3 -> 
STMT_4 -> if\( STMT_4
STMT_4 -> (!>if\() EXP (>\)\{) STMT_4
STMT_4 -> 
```


With optional else:

```
STMT -> (>if\() STMT_2 \} STMT
STMT_2 -> (>if\() STMT_3 (\}else\{|((!>\}else\{)\})) STMT_2
STMT_2 -> (!>if\() STMT (>\}) STMT_2
STMT_2 -> 
STMT_3 -> (>if\() STMT_4 \)\{ STMT_3
STMT_3 -> (!>if\() STMT (>\}else\{|((!>\}else\{)\})) STMT_3
STMT_3 -> 
STMT_4 -> if\( STMT_4
STMT_4 -> (!>if\() EXP (>\)\{) STMT_4
STMT_4 ->
```

### Applied if/else bracketless example

```
STMT -> if( EXP ) STMT else STMT
```
=>
```
STMT -> (>if\() STMT_2 else STMT
STMT_2 -> (>if\() STMT_3 \) STMT_3
STMT_2 -> (!>if\() STMT (>else) STMT_3
STMT_2 -> 
STMT_3 -> if\( STMT_3
STMT_3 -> (!>if\() EXP (>\)) STMT_3
STMT_3 -> 
```

### Applied for loop example

```
STMT -> for\( EXPCOMMA ; EXPCOMMA ; EXPCOMMA \) STMT
EXPCOMMA -> {Expression ","}*
```
= {aspects concerning this transformation}
```
STMT -> for\( EXPCOMMA ; EXPCOMMA ; EXPCOMMA \)
```
=>
```
STMT -> (>for\() STMT_2 \)
STMT_2 -> (>for\() STMT_3 ; STMT_2
STMT_2 -> (!>for\() EXPCOMMA (>\)) STMT_2
STMT_2 ->
STMT_3 -> (>for\() STMT_4 ; STMT_3
STMT_3 -> (!>for\() EXPCOMMA (>;) STMT_3
STMT_3 ->
STMT_4 -> for\( STMT_4
STMT_4 -> (!>for\() EXPCOMMA (>;) STMT_4
STMT_4 ->
```


### Observed drawback

This technique doesn't allow for self recursion. E.g. `A -> X A Y A` is problematic. 


## Technique 4
A production `A -> X_1 B_1 X_2 B_2 ... X_k B_k X_{k+1} A` can be simulated accurately if:
- `X_1` does not overlap with any `X_i` for `i ∈ [2..k]`
- `X_1` does not overlap with any production of `B_i`, for any `i ∈ [2..k]`
- `X_{i+1}` does not overlap any production of `B_i`, for any `i ∈ [1..k]`

We translate this rule to:
```
A -> (>X_1) A_1 X_{k+1} A
A_1 -> (>X_1) A_2 X_k A_1
A_1 -> (!>X_1) B_k (>X_{k+1}) A_1
A_1 -> 
A_2 -> (>X_1) A_3 X_{k-1} A_2
A_2 -> (!>X_1) B_{k-1} (>X_k) A_2
A_2 -> 
...
A_k -> X_1 B_1 (>X_2) A_k
A_k -> 
```


### Applied for loop example

```
STMT -> for\( EXPCOMMA ; EXPCOMMA ; EXPCOMMA \) STMT
EXPCOMMA -> {Expression ","}*
```
=>
```
STMT -> (>for\() STMT_2 \) STMT
STMT_2 -> (>for\() STMT_3 ; STMT_2
STMT_2 -> (!>for\() EXPCOMMA (>\)) STMT_2
STMT_2 ->
STMT_3 -> (>for\() STMT_4 ; STMT_3
STMT_3 -> (!>for\() EXPCOMMA (>;) STMT_3
STMT_3 ->
STMT_4 -> for\( EXPCOMMA (>;) STMT_4
STMT_4 ->
```

### Observed drawback

This technique still doesn't allow for all self-recursion, but does allow for slightly more self-recursion. E.g. `A -> X A Y A Z A` is problematic, but `A -> X A Y B Z A` is fine.

## Technique 5

A production `A -> X_1 B_1 X_2 B_2 ... X_k B_k X_{k+1} A` can be simulated accurately if:
- `X_{k+1}` does not overlap with any `X_i` for `i ∈ [2..k]`
- `X_{k+1}` does not overlap with any production of `B_i` for `i ∈ [1..k]`
- `X_i` does not overlap with any production of `B_i` for `i ∈ [1..k]`

We translate this rule to:
```
A -> X_1 A_1 X_{k+1} A
A_1 -> ...B_1
A_1 -> X_2 A_2 (>X_{k+1}) A_1
A_2 -> ...B_2
A_2 -> X_3 A_3 (>X_{k+1}) A_2
...
A_{k-1} -> ...B_{k-1}
A_{k-1} -> X_k B_k (>X_{k+1}) A_{k-1}
```

Note that the suffix `(>X_{k+1})` isn't strictly necessary. We can instead specify
E.g. `A_1 -> X_2 A_2`, and a later transformation can make sure to add this suffix for TM like languages, while leaving it out for state-based languages (that can deal with state changes natively).

### Applied for loop example

```
STMT -> for \( EXP in EXP , COND\) STMT
```
=>
```
STMT -> for \( STMT_2 \) STMT
STMT_2 -> ...EXP
STMT_2 -> in STMT_3 (> \))
STMT_3 -> ...EXP
STMT_3 -> , COND (> \))
```

Now if `in` is already is a prefix of EXP, we would get the following after overlap fixing:
```
STMT -> for \( STMT_2 \) STMT
STMT_2 -> ...EXP\{in}
STMT_2 -> in UR<STMT_2|STMT_3|(> \))>
UR<STMT_2|STMT_3|(> \))> -> ...EXP
UR<STMT_2|STMT_3|(> \))> -> , COND (> \))
```

## Technique 6
In some cases we simply can't adhere to the specified structure without causing non-determinism. In this case we can simply broaden the language by allowing any order of elements. 