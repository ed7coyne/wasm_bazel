"""Repository rule to create wrapper scripts for wasi_sdk tools."""

def _wasi_sdk_wrapper_impl(repository_ctx):
    """Creates wrapper scripts for wasi_sdk tools in this repository."""
    
    # Create the bin directory
    repository_ctx.file("bin/.gitkeep", "")
    
    # Get the wasi_sdk path - we'll use a relative path from the execution root
    wasi_sdk_path = "external/wasm_toolchain++_repo_rules2+wasi_sdk"
    
    # Create wrapper scripts for each tool
    tools = [
        ("clang", "bin/clang"),
        ("clang++", "bin/clang++"),
        ("wasm-ld", "bin/wasm-ld"),
        ("llvm-ar", "bin/llvm-ar"),
        ("llvm-nm", "bin/llvm-nm"),
        ("llvm-objcopy", "bin/llvm-objcopy"),
        ("llvm-objdump", "bin/llvm-objdump"),
        ("llvm-strip", "bin/llvm-strip"),
    ]
    
    for tool_name, tool_path in tools:
        wrapper_content = """#!/bin/bash
exec "$(dirname "$0")/../../{wasi_sdk_path}/{tool_path}" "$@"
""".format(wasi_sdk_path = wasi_sdk_path, tool_path = tool_path)
        repository_ctx.file("bin/" + tool_name, wrapper_content, executable = True)
    
    # Create BUILD file
    build_content = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_tools",
    srcs = glob(["bin/*"]),
)

exports_files(glob(["bin/*"]))
"""
    repository_ctx.file("BUILD.bazel", build_content)

wasi_sdk_wrapper = repository_rule(
    implementation = _wasi_sdk_wrapper_impl,
    attrs = {},
)
