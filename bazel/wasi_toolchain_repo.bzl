"""Repository rule to create a WASI toolchain with correct tool paths."""

_BUILD_FILE_CONTENT = """
package(default_visibility = ["//visibility:public"])

load("@wasm_toolchain//bazel:toolchain_config.bzl", "wasm32_wasi_toolchain_config")

wasm32_wasi_toolchain_config(
    name = "wasm32_wasi_toolchain_config",
    clang = "@wasi_sdk//:bin/clang",
    clang_pp = "@wasi_sdk//:bin/clang++",
    wasm_ld = "@wasi_sdk//:bin/wasm-ld",
    llvm_ar = "@wasi_sdk//:bin/llvm-ar",
    llvm_nm = "@wasi_sdk//:bin/llvm-nm",
    llvm_objcopy = "@wasi_sdk//:bin/llvm-objcopy",
    llvm_objdump = "@wasi_sdk//:bin/llvm-objdump",
    llvm_strip = "@wasi_sdk//:bin/llvm-strip",
    sysroot_include = "@wasi_sdk//:share/wasi-sysroot/include/wasm32-wasi/stdint.h",
)

platform(
    name = "wasm32_wasi",
    constraint_values = [
        "@platforms//os:wasi",
        "@platforms//cpu:wasm32",
    ],
)

toolchain(
    name = "wasm32-wasi-toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:aarch64",
    ],
    target_compatible_with = [
        "@platforms//os:wasi",
        "@platforms//cpu:wasm32",
    ],
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    toolchain = ":wasm32_wasi_cc_toolchain",
)

cc_toolchain(
    name = "wasm32_wasi_cc_toolchain",
    toolchain_identifier = "wasm32-wasi",
    toolchain_config = ":wasm32_wasi_toolchain_config",
    all_files = "@wasi_sdk//:everything",
    ar_files = "@wasi_sdk//:everything",
    as_files = "@wasi_sdk//:everything",
    compiler_files = "@wasi_sdk//:everything",
    dwp_files = ":empty",
    linker_files = "@wasi_sdk//:everything",
    objcopy_files = "@wasi_sdk//:everything",
    strip_files = "@wasi_sdk//:everything",
    supports_param_files = 0,
)

filegroup(name = "empty")
"""

def _wasi_toolchain_repo_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", _BUILD_FILE_CONTENT)

wasi_toolchain_repo = repository_rule(
    implementation = _wasi_toolchain_repo_impl,
    attrs = {},
)
