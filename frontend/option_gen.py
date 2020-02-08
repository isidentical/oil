#!/usr/bin/env python2
"""
option_gen.py
"""
from __future__ import print_function

import sys

from asdl.visitor import FormatLines
from frontend import option_def


def _CreateModule(option_names):
  """ 
  Create a SYNTHETIC ASDL module to generate code from.

  Similar to frontend/id_kind_gen.py

  C++:

  using option_asdl::option
  option::nounset

  Python:
  from _devbuild.gen.option_asdl import option
  option.nounset
  """
  from asdl import asdl_

  # oil:basic -> oil_basic
  option_sum = asdl_.Sum(
      [asdl_.Constructor(name.replace(':', '_')) for name in option_names])

  option = asdl_.Type('option', option_sum)
  schema_ast = asdl_.Module('option', [], [option])
  return schema_ast


def main(argv):
  try:
    action = argv[1]
  except IndexError:
    raise RuntimeError('Action required')

  # TODO:
  # generate builtin::echo, etc.
  # 
  # And in Python do the same.


  schema_ast = _CreateModule(option_def.ALL_OPTION_NAMES)

  if action == 'cpp':
    from asdl import gen_cpp

    out_prefix = argv[2]

    with open(out_prefix + '.h', 'w') as f:
      f.write("""\
#ifndef OPTION_ASDL_H
#define OPTION_ASDL_H

namespace option_asdl {
""")

      # TODO: Could suppress option_str
      v = gen_cpp.ClassDefVisitor(f, {}, e_suffix=False,
                                  simple_int_sums=['option'])
      v.VisitModule(schema_ast)

      f.write("""
}  // namespace option_asdl

#endif  // OPTION_ASDL_H
""")

    with open(out_prefix + '.cc', 'w') as f:
      f.write("""\
#include <assert.h>
#include "option_asdl.h"

namespace option_asdl {

""")

      v = gen_cpp.MethodDefVisitor(f, {}, e_suffix=False,
                                   simple_int_sums=['option'])

      v.VisitModule(schema_ast)

      f.write('}  // namespace option_asdl\n')

  elif action == 'mypy':
    from asdl import gen_python

    f = sys.stdout

    f.write("""\
from asdl import pybase

""")
    # Minor style issue: we want Id and Kind, not Id_e and Kind_e
    v = gen_python.GenMyPyVisitor(f, None, e_suffix=False,
                                  simple_int_sums=['option'])
    v.VisitModule(schema_ast)

  elif action == 'cc-tables':
    pass

  elif action == 'py-tables':
    pass

  else:
    raise RuntimeError('Invalid action %r' % action)


if __name__ == '__main__':
  try:
    main(sys.argv)
  except RuntimeError as e:
    print('FATAL: %s' % e, file=sys.stderr)
    sys.exit(1)