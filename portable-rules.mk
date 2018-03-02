# portable-rules.mk: These are done on the dev machine.
# 
# Non-portable rules involves C compilers, and must be done on the target
# machine.

#
# App-independent rules.
#

# NOTES:
# - Manually rm this file to generate a new build timestamp.
# - This messes up reproducible builds.
# - It's not marked .PHONY because that would mess up the end user build.
#   bytecode-*.zip should NOT be built by the user.
_build/release-date.txt:
	$(ACTIONS_SH) write-release-date

# The Makesfiles generated by autoconf don't call configure, but Linux/toybox
# config system does.  This can be overridden.
_build/detected-config.sh:
	./configure

# What files correspond to each C module.
# TODO:
# - Where to put -l z?  (Done in Modules/Setup.dist)
_build/c-module-toc.txt: build/c_module_toc.py
	$(ACTIONS_SH) c-module-toc > $@

# Python and C dependencies of runpy.
# NOTE: This is done with a pattern rule because of the "multiple outputs"
# problem in Make.
_build/runpy-deps-%.txt: build/runpy_deps.py
	$(ACTIONS_SH) runpy-deps _build

_build/py-to-compile.txt: build/runpy_deps.py
	$(ACTIONS_SH) runpy-py-to-compile > $@

#
# Hello App.
#

# C module dependencies
-include _build/hello/ovm.d

# What Python module to run.
_build/hello/main_name.c:
	$(ACTIONS_SH) main-name hello hello.ovm > $@

# Dependencies calculated by importing main.  The guard is because ovm.d
# depends on it.  Is that correct?  We'll skip it before 'make dirs'.
_build/hello/app-deps-%.txt: $(HELLO_SRCS) \
	_build/detected-config.sh build/app_deps.py
	test -d _build/hello && \
	  $(ACTIONS_SH) app-deps hello build/testdata hello

_build/hello/py-to-compile.txt: \
	_build/detected-config.sh build/app_deps.py
	test -d _build/hello && \
	  $(ACTIONS_SH) py-to-compile build/testdata hello > $@

# NOTE: We could use src/dest paths pattern instead of _build/app?
#
# TODO:
# - Deps need to be better.  Depend on .pyc and .py.    I guess
#   app-deps hello will compile the .pyc files.  Don't need a separate action.
#   %.pyc : %py

HELLO_BYTECODE_DEPS := \
	build/testdata/hello-version.txt \
        _build/release-date.txt \
	build/testdata/hello-manifest.txt

_build/hello/bytecode-cpython.zip: $(HELLO_SRCS) $(HELLO_BYTECODE_DEPS) \
                           _build/hello/app-deps-cpython.txt \
                           _build/runpy-deps-cpython.txt
	{ echo 'build/testdata/hello-version.txt hello-version.txt'; \
	  echo '_build/release-date.txt release-date.txt'; \
	  cat build/testdata/hello-manifest.txt \
	      _build/hello/app-deps-cpython.txt \
	      _build/runpy-deps-cpython.txt; \
	} | build/make_zip.py $@

_build/hello/bytecode-opy.zip: $(HELLO_SRCS) $(HELLO_BYTECODE_DEPS) \
                           _build/hello/opy-app-deps.txt
	{ echo 'build/testdata/hello-version.txt hello-version.txt'; \
	  echo '_build/release-date.txt release-date.txt'; \
	  cat build/testdata/hello-manifest.txt \
	      _build/hello/opy-app-deps.txt; \
	} | build/make_zip.py $@

#
# Oil App.
#

# C module dependencies
-include _build/oil/ovm.d

_build/oil/main_name.c:
	$(ACTIONS_SH) main-name bin.oil oil.ovm > $@

# The root of this repo, e.g. ~/git/oil, should be our PYTHONPATH for
# detecting dependencies.
# 
# From this link:
# https://stackoverflow.com/questions/322936/common-gnu-makefile-directory-path
# Except we're using 'firstword' instead of 'lastword', because
# _build/oil/ovm.d is the last one.
REPO_ROOT := $(abspath $(dir $(firstword $(MAKEFILE_LIST))))

# Dependencies calculated by importing main.
# NOTE: The list of files is used both to compile and to make a tarball.
# - For compiling, we should respect _HAVE_READLINE in detected_config
# - For the tarball, we should ALWAYS include readline.
#
# BUG: Running 'make' the first time files because it can't find the '_build'
# package.  build/doc.sh currently makes _build/__init__.py.
_build/oil/app-deps-%.txt: _build/detected-config.sh build/app_deps.py
	test -d _build/oil && \
	  $(ACTIONS_SH) app-deps oil $(REPO_ROOT) bin.oil

_build/oil/py-to-compile.txt: _build/detected-config.sh build/app_deps.py
	test -d _build/oil && \
	  $(ACTIONS_SH) py-to-compile $(REPO_ROOT) bin.oil > $@

_devbuild/gen/osh_help.py: doc/osh-quick-ref-pages.txt
	build/doc.sh osh-quick-ref

# NOTE: I should really depend on every file in build/oil-manifest.txt!
OIL_BYTECODE_DEPS := \
	_build/release-date.txt \
	build/oil-manifest.txt \
	_devbuild/gen/osh_help.py

# NOTES:
# - _devbuild/gen/osh_help.py is a minor hack to depend on the entire
#   _devbuild/osh-quick-ref dir, since they both get generated by the same
#   build action.  (Hidden targets are known to cause problems with GNU Make.)
# - release-date.txt is in different location on purpose, so we don't show it
#   in dev mode.
# - Do we need $(OIL_SRCS) as dependencies?

_build/oil/bytecode-cpython-manifest.txt: $(OIL_BYTECODE_DEPS) \
                         _build/oil/app-deps-cpython.txt \
                         _build/runpy-deps-cpython.txt
	{ echo '_build/release-date.txt release-date.txt'; \
	  cat build/oil-manifest.txt \
	      _build/oil/app-deps-cpython.txt \
	      _build/runpy-deps-cpython.txt; \
	  $(ACTIONS_SH) quick-ref-manifest _devbuild/osh-quick-ref; \
	  $(ACTIONS_SH) pyc-version-manifest $@; \
	} > $@

# NOTE: runpy deps are included in opy-app-deps.txt.
_build/oil/bytecode-opy-manifest.txt: $(OIL_BYTECODE_DEPS) \
                         _build/oil/opy-app-deps.txt
	{ echo '_build/release-date.txt release-date.txt'; \
	  cat build/oil-manifest.txt \
	      _build/oil/opy-app-deps.txt; \
	  $(ACTIONS_SH) quick-ref-manifest _devbuild/osh-quick-ref; \
	  $(ACTIONS_SH) pyc-version-manifest $@; \
	} > $@

_build/oil/bytecode-%.zip: _build/oil/bytecode-%-manifest.txt
	build/make_zip.py $@ < $^

#
# App-Independent Pattern Rules.
#

# Regenerate dependencies.  But only if we made the app dirs.
_build/%/ovm.d: _build/%/app-deps-c.txt
	$(ACTIONS_SH) make-dotd $* $^ > $@

# Source paths of all C modules the app depends on.  For the tarball.
# A trick: remove the first dep to form the lists.  You can't just use $^
# because './c_module_srcs.py' is rewritten to 'c_module_srcs.py'.
_build/%/c-module-srcs.txt: \
	build/c_module_srcs.py _build/c-module-toc.txt _build/%/app-deps-c.txt
	build/c_module_srcs.py $(filter-out $<,$^) > $@

_build/%/all-deps-c.txt: build/static-c-modules.txt _build/%/app-deps-c.txt
	$(ACTIONS_SH) join-modules $^ > $@

# NOTE: This should really depend on all the .py files.
# I should make a _build/oil/py.d file and include it?
_build/%/opy-app-deps.txt: \
	_build/py-to-compile.txt _build/%/py-to-compile.txt
	sort $^ | uniq | opy/build.sh compile-manifest _build/$*-with-opy > $@


PY27 := Python-2.7.13

# Per-app extension module initialization.
_build/%/module_init.c: $(PY27)/Modules/config.c.in _build/%/all-deps-c.txt
	# NOTE: Using xargs < input.txt style because it will fail if input.txt
	# doesn't exist!  'cat' errors will be swallowed.
	xargs $(ACTIONS_SH) gen-module-init < _build/$*/all-deps-c.txt > $@


# 
# Tarballs
#
# Contain Makefile and associated shell scripts, discovered .c and .py deps,
# app source.

_release/%.tar: _build/%/$(BYTECODE_ZIP) \
                _build/%/module_init.c \
                _build/%/main_name.c \
                _build/%/c-module-srcs.txt
	$(COMPILE_SH) make-tar $* $(BYTECODE_ZIP) $@

