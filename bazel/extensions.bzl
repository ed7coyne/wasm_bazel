# bazel/extensions.bzl
"""Module extension for setting up the WASM toolchain."""

load("//bazel:unified_toolchain.bzl", "wasm_toolchain_repo")

def _wasm_impl(mctx):
    """Implementation of the wasm module extension."""
    
    # Create the toolchain repository with symlinks to the WASI SDK
    wasm_toolchain_repo(
        name = "wasm_toolchain_configured",
        wasi_sdk = "@wasi_sdk//:bin/clang",
    )

wasm = module_extension(
    implementation = _wasm_impl,
)
