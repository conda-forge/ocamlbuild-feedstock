#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ==============================================================================
# ocamlbuild Build Script
# ==============================================================================
# Uses standardized build_functions.sh for cross-feedstock consistency.
# Requires ocaml _12+ for proper ocamlmklib behavior (rpath, CONDA_OCAML_*).
# ==============================================================================

is_macos() { [[ "${target_platform}" == "osx-"* ]]; }
is_linux() { [[ "${target_platform}" == "linux-"* ]]; }
is_unix() { is_linux || is_macos; }
is_non_unix() { ! is_unix; }
is_cross_compile() { [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; }

warn() { echo "WARNING: $*" >&2; }
fail() { echo "ERROR: $*" >&2; exit 1; }

setup_ocaml_env() {
  if is_unix; then
    export OCAMLLIB="${BUILD_PREFIX}/lib/ocaml"
    export HOST_PREFIX="${PREFIX}"
  else
    # Windows paths use Library subdirectory.
    # BUILD_PREFIX arrives backslashed (D:\bld\...) from rattler-build; the OCaml
    # tools accept it, but Make chokes on the drive colon in an include path, so
    # derive an MSYS2-form (/d/...) copy here. recipe/build.bat used to supply this
    # as _BUILD_PREFIX; it no longer exists, so build.sh must be self-contained.
    _bp="${BUILD_PREFIX//\\//}"
    _drive="${_bp:0:1}"
    export OCAML_PREFIX="${_bp}/Library"
    export OCAMLLIB="${_bp}/Library/lib/ocaml"
    export OCAMLLIB_MSYS="/${_drive,,}${_bp:2}/Library/lib/ocaml"
    export HOST_PREFIX="${PREFIX}/Library"
    # Stublibs path for bytecode DLLs (dllunixbyt.dll, etc.)
    export CAML_LD_LIBRARY_PATH="${OCAMLLIB}/stublibs"
  fi
}

fix_rattler_paths() {
  if is_non_unix; then
    for file in "$@"; do
      if [[ -f "${file}" ]]; then
        sed -i -E "s#(=)[^\|]*rattler-build_ocaml_[^\|]*Library#\1${PREFIX}/Library#g" "${file}"
        sed -i -E "s#(\|)[^\|]*rattler-build_ocaml_[^\|]*Library#\1${PREFIX}/Library#g" "${file}"
      fi
    done
  fi
}

setup_ocaml_env

export OCAMLBUILD_PREFIX=${HOST_PREFIX}
export OCAMLBUILD_BINDIR=${OCAMLBUILD_PREFIX}/bin
export OCAMLBUILD_LIBDIR=${OCAMLBUILD_PREFIX}/lib/ocaml
export OCAMLBUILD_MANDIR=${OCAMLBUILD_PREFIX}/share/man

# On Windows, configure.make runs "include $(shell ocamlc -where)/Makefile.config".
# The ocaml package ships that file with its install-directory assignments already
# corrupted: the prefix and MANDIR lines carry a D:-rooted path whose separators have
# been lost and which contains embedded control characters. Make then reads a line
# starting "D:" with no "=" as a rule, and reports
#   No rule to make target '...', needed by 'D'.
# Backslash conversion cannot help - those bytes are no longer backslashes. Copy the
# file in, strip the control characters, drop the corrupt assignments, re-declare the
# install dirs configure.make actually reads, and include the local copy.
if is_non_unix; then
  cp "${OCAMLLIB_MSYS}/Makefile.config" ./Makefile.config.ocaml
  tr -d '\r\b' < ./Makefile.config.ocaml > ./Makefile.config.tmp
  mv ./Makefile.config.tmp ./Makefile.config.ocaml
  sed -i -E '/^[A-Za-z]:/d' ./Makefile.config.ocaml
  sed -i -E '/^(prefix|exec_prefix|BINDIR|LIBDIR|STUBLIBDIR|MANDIR)[[:space:]]*=/d' ./Makefile.config.ocaml
  {
    echo "prefix=${OCAML_PREFIX}"
    echo "exec_prefix=${OCAML_PREFIX}"
    echo "BINDIR=${OCAML_PREFIX}/bin"
    echo "LIBDIR=${OCAML_PREFIX}/lib/ocaml"
    echo "STUBLIBDIR=${OCAML_PREFIX}/lib/ocaml/stublibs"
    echo "MANDIR=${OCAML_PREFIX}/share/man"
  } >> ./Makefile.config.ocaml
  sed -i "s|include \$(shell ocamlc -where)/Makefile.config|include Makefile.config.ocaml|" configure.make
fi

# Configure
make -f configure.make

# Fix Windows rattler-build paths if needed
fix_rattler_paths "${SRC_DIR}/Makefile.config" "${SRC_DIR}/src/ocamlbuild_config.ml"

# Build
make configure
# all and install-lib follow OCAML_NATIVE from Makefile.config (false on win-arm64).
make all

# Install
if [[ "${target_platform}" == "win-arm64" ]]; then
  make install-bin-byte install-lib install-man
else
  make install-bin-native install-lib install-man
fi
