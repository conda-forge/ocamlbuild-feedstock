# ==============================================================================
# OCaml Build Helper Functions
# ==============================================================================
# Standardized helper functions for OCaml conda-forge feedstocks.
# Sourced by build.sh for cleaner organization and cross-feedstock consistency.
# ==============================================================================

# ==============================================================================
# PLATFORM DETECTION
# ==============================================================================

is_macos() { [[ "${target_platform}" == "osx-"* ]]; }
is_linux() { [[ "${target_platform}" == "linux-"* ]]; }
is_unix() { is_linux || is_macos; }
is_non_unix() { ! is_unix; }
is_cross_compile() { [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; }

# ==============================================================================
# ERROR HANDLING
# ==============================================================================

warn() {
  echo "WARNING: $*" >&2
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================

# Set up standard OCaml path variables
# Call this at the start of build.sh after sourcing this file
# Note: ocaml _12+ handles rpath and ocamlmklib flags correctly
setup_ocaml_env() {
  if is_unix; then
    export OCAMLLIB="${BUILD_PREFIX}/lib/ocaml"
    export HOST_PREFIX="${PREFIX}"
  else
    # Windows paths use Library subdirectory
    export OCAML_PREFIX="${_BUILD_PREFIX_}/Library"
    export OCAMLLIB="${_BUILD_PREFIX_}/Library/lib/ocaml"
    export HOST_PREFIX="${_PREFIX_}/Library"
    # Stublibs path for bytecode DLLs (dllunixbyt.dll, etc.)
    export CAML_LD_LIBRARY_PATH="${OCAMLLIB}/stublibs"
  fi
}

# ==============================================================================
# WINDOWS WORKAROUNDS
# ==============================================================================

# Fix rattler-build paths in generated config files (Windows only)
# Usage: fix_rattler_paths FILE...
fix_rattler_paths() {
  if is_non_unix; then
    for file in "$@"; do
      if [[ -f "${file}" ]]; then
        sed -i -E "s#(=)[^\|]*rattler-build_ocaml_[^\|]*Library#\1${_PREFIX_}/Library#g" "${file}"
        sed -i -E "s#(\|)[^\|]*rattler-build_ocaml_[^\|]*Library#\1${_PREFIX_}/Library#g" "${file}"
      fi
    done
  fi
}
