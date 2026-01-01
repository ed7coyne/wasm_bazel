# bazel/wasm_toolchain.bzl
"""Repository rule for setting up the WASM toolchain.

This creates a repository with symlinks to the WASI SDK tools, allowing
the toolchain to work correctly when used as an external dependency.
"""

# Tools that need to be symlinked from the WASI SDK
_TOOLS = [
    "clang",
    "clang++",
    "wasm-ld",
    "llvm-ar",
    "llvm-nm",
    "llvm-objcopy",
    "llvm-objdump",
    "llvm-strip",
]

def _wasm_toolchain_repo_impl(rctx):
    """Implementation of the wasm_toolchain_repo repository rule."""
    
    # Get the path to the WASI SDK
    # The wasi_sdk label points to a file in the bin directory, so we need to go up twice
    # to get to the SDK root (bin/clang -> bin -> sdk_root)
    wasi_sdk_bin_path = rctx.path(rctx.attr.wasi_sdk).dirname
    wasi_sdk_path = wasi_sdk_bin_path.dirname
    
    # Create bin directory and symlink tools
    rctx.execute(["mkdir", "-p", "bin"])
    for tool_name in _TOOLS:
        src = str(wasi_sdk_path) + "/bin/" + tool_name
        dst = "bin/" + tool_name
        rctx.symlink(src, dst)
    
    # Symlink the sysroot
    sysroot_src = str(wasi_sdk_path) + "/share/wasi-sysroot"
    rctx.symlink(sysroot_src, "sysroot")
    
    # Symlink the clang lib directory (for clang headers)
    lib_src = str(wasi_sdk_path) + "/lib"
    rctx.symlink(lib_src, "lib")
    
    # The repository path prefix for use in flags (sysroot, include paths)
    # These need to be relative to the execution root
    # In bzlmod, the repo name includes the module extension prefix
    repo_path_prefix = "external/" + rctx.name + "/"
    
    # Generate the BUILD file with the correct paths embedded
    # Note: tool paths in action_config are relative to the cc_toolchain package,
    # so they should NOT include the repo prefix (just "bin/")
    # But sysroot and include paths are passed as flags and need the full path
    build_content = '''
package(default_visibility = ["//visibility:public"])

load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load("@wasm_toolchain//bazel:toolchain_config.bzl", "wasm32_wasi_toolchain_config")

# Filegroup for all tools
filegroup(
    name = "all_tools",
    srcs = glob(["bin/*"]) + glob(["sysroot/**"]) + glob(["lib/**"]),
)

filegroup(name = "empty")

wasm32_wasi_toolchain_config(
    name = "wasm32_wasi_toolchain_config",
    # Tool paths are relative to this package (cc_toolchain location)
    tools_path_prefix = "bin/",
    # Sysroot and lib paths need full path from execution root (for flags)
    sysroot_path = "{repo_path_prefix}sysroot",
    lib_path = "{repo_path_prefix}lib",
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
    all_files = ":all_tools",
    ar_files = ":all_tools",
    as_files = ":all_tools",
    compiler_files = ":all_tools",
    dwp_files = ":empty",
    linker_files = ":all_tools",
    objcopy_files = ":all_tools",
    strip_files = ":all_tools",
    supports_param_files = 0,
)
'''.format(repo_path_prefix = repo_path_prefix)
    rctx.file("BUILD.bazel", build_content)

wasm_toolchain_repo = repository_rule(
    implementation = _wasm_toolchain_repo_impl,
    attrs = {
        "wasi_sdk": attr.label(
            doc = "Label to a file in the WASI SDK bin directory (used to find the SDK root)",
            mandatory = True,
        ),
    },
    doc = "Creates a repository with symlinks to WASI SDK tools for the WASM toolchain.",
)
