## Fll allows you to create short aliases for directory paths. Then next time you need to navigate there you can use the alias instead!

Fll is a simple yet powerful utility program -
designed specifically for Linux terminal users.
Fll allows you to create bookmarks for frequently used directory paths,
making it easier and faster to navigate within a terminal.

This cli program will save you time and hassle, especially if you work with deep directory structures.

### example usage:
``` console
user@test-user:/$ fll path1 this/is/a/sample/path/ # sets alias "path1"
user@test-user:/$ fll path1                        # changes directory using the alias "path1"
user@test-user:/this/is/a/sample/path$ 
```

## Install
``` console
git clone https://github.com/Ryan-AW/fll ~/fll
```
then add these two lines to your ~/.bashrc file (or ~/.zshrc if you use Zsh):
``` console
alias fll='source ~/fll/fll.sh'
source "${HOME}/fll/fll_completion.sh"
```
**important**
Ensure that the path points to where you cloned the repository.

(Note: You need to restart your terminal or run `source ~/.bashrc` (or `source ~/.zshrc` if you use Zsh) for the changes to take effect.)

**warning**
This program must be run as a source file otherwise it will not work.
