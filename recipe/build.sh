#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ==============================================================================
# ocamlbuild Build Script
# ==============================================================================
# Uses standardized build_functions.sh for cross-feedstock consistency.
# Requires ocaml _12+ for proper ocamlmklib behavior (rpath, CONDA_OCAML_*).
# ==============================================================================

source "${RECIPE_DIR}/building/build_functions.sh"

setup_ocaml_env

export OCAMLBUILD_PREFIX=${HOST_PREFIX}
export OCAMLBUILD_BINDIR=${OCAMLBUILD_PREFIX}/bin
export OCAMLBUILD_LIBDIR=${OCAMLBUILD_PREFIX}/lib/ocaml
export OCAMLBUILD_MANDIR=${OCAMLBUILD_PREFIX}/share/man

# On Windows, configure.make runs "include $(shell ocamlc -where)/Makefile.config"
# which fails because ocamlc returns D:/... paths and Make interprets D: as a target rule.
# Fix: replace the shell call with our MSYS2-safe OCAMLLIB path.
if is_non_unix; then
  sed -i "s|include \$(shell ocamlc -where)/Makefile.config|include ${OCAMLLIB_MSYS}/Makefile.config|" configure.make
fi

# Configure
make -f configure.make

# Fix Windows rattler-build paths if needed
fix_rattler_paths "${SRC_DIR}/Makefile.config" "${SRC_DIR}/src/ocamlbuild_config.ml"

# Build
make configure
make native byte man

# Install
make install-bin-native install-lib install-man
