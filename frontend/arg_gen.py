#!/usr/bin/env python2
"""
arg_gen.py
"""
from __future__ import print_function

import sys

from _devbuild.gen.runtime_asdl import flag_type_e, value_e
from core.util import log
from frontend import arg_def
from mycpp.mylib import tagswitch


def CString(s):
  # HACK for now
  assert '"' not in s, s
  assert '\\' not in s, s

  return '"%s"' % s


def Cpp(specs, header_f, cc_f):
  header_f.write("""\
// arg_types.h is generated by frontend/arg_gen.py

#ifndef ARG_TYPES_H
#define ARG_TYPES_H

#include "frontend_arg_def.h"  // for FlagSpec_c
#include "mylib.h"

namespace value_e = runtime_asdl::value_e;
using runtime_asdl::value__Bool;
using runtime_asdl::value__Str;

namespace arg_types {
""")
  for spec_name in sorted(specs):
    spec = specs[spec_name]

    if not spec.fields:
      continue  # skip empty 'eval' spec

    header_f.write("""
class %s {
 public:
  %s(Dict<Str*, runtime_asdl::value_t*>* attrs) :
""" % (spec_name, spec_name))

    init_vals = []
    field_decls = []
    for field_name in sorted(spec.fields):
      typ = spec.fields[field_name]

      with tagswitch(typ) as case:
        if case(flag_type_e.Bool):
          init_vals.append('static_cast<value__Bool*>(attrs->index(new Str("%s")))->b' % field_name)
          field_decls.append('bool %s;' % field_name)

        elif case(flag_type_e.Str):
          # TODO: This code is ugly and inefficient!  Generate something
          # better.  At least get rid of 'new' everywhere?
          init_vals.append('''\
attrs->index(new Str("%s"))->tag_() == value_e::Undef
      ? nullptr
      : static_cast<value__Str*>(attrs->index(new Str("%s")))->s''' % (field_name, field_name))

          field_decls.append('Str* %s;' % field_name)

        else:
          raise AssertionError(typ)

    for i, field_name in enumerate(sorted(spec.fields)):
      if i != 0:
        header_f.write(',\n')
      header_f.write('    %s(%s)' % (field_name, init_vals[i]))
    header_f.write(' {\n')
    header_f.write('  }\n')

    for decl in field_decls:
      header_f.write('  %s\n' % decl)

    header_f.write("""\
};
""")

  header_f.write("""
extern FlagSpec_c kFlagSpecs[];

}  // namespace arg_types

#endif  // ARG_TYPES_H

""")

  cc_f.write("""\
// arg_types.cc is generated by frontend/arg_gen.py

#include "arg_types.h"

namespace arg_types {

""")

  var_names = []
  for i, spec_name in enumerate(sorted(specs)):
    spec = specs[spec_name]
    arity0_name = None
    arity1_name = None
    options_name = None
    defaults_name = None

    if spec.arity0:
      arity0_name = 'arity0_%d' % i
      c_strs = ', '.join(CString(s) for s in sorted(spec.arity0))
      cc_f.write('const char* %s[] = {%s, nullptr};\n' % (arity0_name, c_strs))

    if spec.arity1:
      arity1_name = 'arity1_%d' % i
      cc_f.write('SetToArg_c %s[] = {\n' % arity1_name)
      for name in sorted(spec.arity1):
        set_to_arg = spec.arity1[name]

        # Using an itnger here
        # TODO: doesn't work for enum flag_type::Enum(...)
        f2 = set_to_arg.flag_type.tag_()

        cc_f.write('    {"%s", %s, %s},' % (name, f2, 'true' if set_to_arg.quit_parsing_flags else 'false'))
      #cc_f.write('SetToArg_c %s[] = {\n' % arity1_name)
      cc_f.write('''\
    {},
};
''')

    if spec.options:
      options_name = 'options_%d' % i
      c_strs = ', '.join(CString(s) for s in sorted(spec.options))
      cc_f.write('const char* %s[] = {%s, nullptr};\n' % (options_name, c_strs))

    if spec.defaults:
      defaults_name = 'defaults_%d' % i
      cc_f.write('DefaultPair_c %s[] = {\n' % defaults_name)
      for name in sorted(spec.defaults):
        val = spec.defaults[name]
        if val.tag_() == value_e.Bool:
          d = 'True' if val.b else 'False'
        elif val.tag_() == value_e.Undef:
          d = 'Undef'
        else:
          raise AssertionError(val)

        cc_f.write('    {%s, Default_c::%s},\n' % (CString(name), d))

      cc_f.write('''\
    {},
};
''')
    var_names.append((arity0_name, arity1_name, options_name, defaults_name))
    cc_f.write('\n')

  cc_f.write('FlagSpec_c kFlagSpecs[] = {\n')

  # Now print a table
  for i, spec_name in enumerate(sorted(specs)):
    spec = specs[spec_name]
    names = var_names[i]
    cc_f.write('    { "%s", %s, %s, %s, %s },\n' % (
      spec_name,
      names[0] or 'nullptr', 
      names[1] or 'nullptr', 
      names[2] or 'nullptr', 
      names[3] or 'nullptr', 
    ))

  cc_f.write("""\
    {},
};

}  // namespace arg_types
""")


def main(argv):
  try:
    action = argv[1]
  except IndexError:
    raise RuntimeError('Action required')

  specs = arg_def.FLAG_SPEC

  for spec_name in sorted(specs):
    spec = specs[spec_name]
    spec.spec.PrettyPrint(f=sys.stderr)
    log('')
    
    log('spec.arity1 %s', spec.spec.arity1)

    log('%s', spec_name)
    #print(dir(spec))
    #print(spec.arity0)
    #print(spec.arity1)
    #print(spec.options)
    # Every flag has a default
    log('%s', spec.fields)

  if action == 'cpp':
    prefix = argv[2]

    with open(prefix + '.h', 'w') as header_f:
      with open(prefix + '.cc', 'w') as cc_f:
        Cpp(specs, header_f, cc_f)

  elif action == 'mypy':
    print("""
from frontend.args import _Attributes
from _devbuild.gen.runtime_asdl import (
   value_e, value_t, value__Bool, value__Int, value__Float, value__Str,
)
from typing import cast, Dict, Optional
""")
    for spec_name in sorted(specs):
      spec = specs[spec_name]

      if not spec.fields:
        continue  # skip empty 'eval' spec

      print("""
class %s(object):
  def __init__(self, attrs):
    # type: (Dict[str, value_t]) -> None
""" % spec_name)

      i = 0
      for field_name in sorted(spec.fields):
        typ = spec.fields[field_name]

        with tagswitch(typ) as case:
          if case(flag_type_e.Bool):
            print('    self.%s = cast(value__Bool, attrs[%r]).b  # type: bool' % (
              field_name, field_name))

          elif case(flag_type_e.Str):
            tmp = 'val%d' % i
            print('    %s = attrs[%r]' % (tmp, field_name))
            print('    self.%s = None if %s.tag_() == value_e.Undef else cast(value__Str, %s).s  # type: Optional[str]' % (field_name, tmp, tmp))
          else:
            raise AssertionError(typ)

        i += 1

      print()

  else:
    raise RuntimeError('Invalid action %r' % action)


if __name__ == '__main__':
  try:
    main(sys.argv)
  except RuntimeError as e:
    print('FATAL: %s' % e, file=sys.stderr)
    sys.exit(1)
