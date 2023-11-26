Before testing, install the custom style in the directory `customStyle`

Direct testing outside latex:
```
pygmentize -l customLexer.py -x -f latex -O style=custom -o export/test.txt customLexer.py
```