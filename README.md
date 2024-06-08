# File Link Language (fll)
## Fll alows you to create short aliases for directory paths. Then next time to need to navigate there you can you the alias instead!

Filepath Link Language (fll) is a simple yet powerful utility program
and scripting language; designed specifically for Linux terminal users.
Fll allows you to create bookmarks for frequently used directory paths,
making it easier and faster to navigate within a terminal.

This cli program will save you time and hassle, especially if you work with deep directory structures.

### example usage:
``` console
user@test-user:/$ fll path1 = this/is/a/sample/path/
user@test-user:/$ fll path1
user@test-user:/this/is/a/sample/path$ 
```


**warning**
This program must be run as a bash source file otherwise it will not be able to change the user's directory.
``` console
alias fll='source /path/to/the/script/fll.sh'
```
