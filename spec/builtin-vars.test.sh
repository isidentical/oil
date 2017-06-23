#!/bin/bash
#
# Tests for builtins having to do with variables: export, readonly, unset, etc.
#
# Also see assign.test.sh.

### Export sets a global variable
# Even after you do export -n, it still exists.
f() { export GLOBAL=X; }
f
echo $GLOBAL
printenv.py GLOBAL
# stdout-json: "X\nX\n"

### Export sets a global variable that persists after export -n
f() { export GLOBAL=X; }
f
echo $GLOBAL
printenv.py GLOBAL
export -n GLOBAL
echo $GLOBAL
printenv.py GLOBAL
# stdout-json: "X\nX\nX\nNone\n"
# N-I mksh/dash stdout-json: "X\nX\n"
# N-I mksh status: 1
# N-I dash status: 2

### Export a global variable and unset it
f() { export GLOBAL=X; }
f
echo $GLOBAL
printenv.py GLOBAL
unset GLOBAL
echo $GLOBAL
printenv.py GLOBAL
# stdout-json: "X\nX\n\nNone\n"

### Export existing global variables
G1=g1
G2=g2
export G1 G2
printenv.py G1 G2
# stdout-json: "g1\ng2\n"

### Export existing local variable
f() {
  local L1=local1
  export L1
  printenv.py L1
}
f
printenv.py L1
# stdout-json: "local1\nNone\n"

### Export a local that shadows a global
V=global
f() {
  local V=local1
  export V
  printenv.py V
}
f
printenv.py V  # exported local out of scope; global isn't exported yet
export V
printenv.py V  # now it's exported
# stdout-json: "local1\nNone\nglobal\n"

### Export a variable before defining it
export U
U=u
printenv.py U
# stdout: u

### Exporting a parent func variable (dynamic scope)
# The algorithm is to walk up the stack and export that one.
inner() {
  export outer_var
  echo "inner: $outer_var"
  printenv.py outer_var
}
outer() {
  local outer_var=X
  echo "before inner"
  printenv.py outer_var
  inner
  echo "after inner"
  printenv.py outer_var
}
outer
# stdout-json: "before inner\nNone\ninner: X\nX\nafter inner\nX\n"

### Dependent export setting
# FOO is not respected here either.
export FOO=foo v=$(printenv.py FOO)
echo "v=$v"
# stdout: v=None

### Exporting a variable doesn't change it
old=$PATH
export PATH
new=$PATH
test "$old" = "$new" && echo "not changed"
# stdout: not changed

### Unset a variable
foo=bar
echo foo=$foo
unset foo
echo foo=$foo
# stdout-json: "foo=bar\nfoo=\n"

### Unset exit status
V=123
unset V
echo status=$?
# stdout: status=0

### Unset nonexistent variable
unset ZZZ
echo status=$?
# stdout: status=0

### Unset readonly variable
# dash aborts the whole program
readonly R=foo
unset R
echo status=$?
# stdout-json: "status=1\n"
# OK dash status: 2
# OK dash stdout-json: ""

### Unset a function without -f
f() {
  echo foo
}
f
unset f
f
# stdout: foo
# status: 127
# N-I dash/mksh status: 0
# N-I dash/mksh stdout-json: "foo\nfoo\n"

### Unset has dynamic scope
f() {
  unset foo
}
foo=bar
echo foo=$foo
f
echo foo=$foo
# stdout-json: "foo=bar\nfoo=\n"

### Unset -v
foo() {
  echo "function foo"
}
foo=bar
unset -v foo
echo foo=$foo
foo
# stdout-json: "foo=\nfunction foo\n"

### Unset -f
foo() {
  echo "function foo"
}
foo=bar
unset -f foo
echo foo=$foo
foo
echo status=$?
# stdout-json: "foo=bar\nstatus=127\n"
