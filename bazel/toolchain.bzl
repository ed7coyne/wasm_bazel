# bazel/toolchain.bzl
"""WASM toolchain configuration for Bazel.

This module provides a cc_toolchain_config rule that configures a WASM/WASI
toolchain using the wasi-sdk. It supports both direct file labels and string paths
for tool references, making it flexible for different usage patterns.
"""

load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", 
     "action_config",
     "feature", 
     "flag_group", 
     "flag_set", 
     "tool",
     "tool_path")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _impl(ctx):
    """Implementation of the wasm32_wasi_toolchain_config rule."""
    
    # Determine if we're using string paths or file labels
    using_string_paths = ctx.attr.tools_path_prefix != ""
    
    # Set up tool paths based on the mode
    if using_string_paths:
        # String paths mode (for symlinked tools)
        tools_prefix = ctx.attr.tools_path_prefix
        sysroot_path = ctx.attr.sysroot_path
        lib_path = ctx.attr.lib_path
        
        # Create action configs with tool paths
        action_configs = [
            action_config(
                action_name = ACTION_NAMES.c_compile,
                tools = [tool(path = tools_prefix + "clang")],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_compile,
                tools = [tool(path = tools_prefix + "clang++")],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_link_executable,
                tools = [tool(path = tools_prefix + "clang++")],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_link_dynamic_library,
                tools = [tool(path = tools_prefix + "clang++")],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                tools = [tool(path = tools_prefix + "clang++")],
            ),
            action_config(
                action_name = ACTION_NAMES.assemble,
                tools = [tool(path = tools_prefix + "clang")],
            ),
            action_config(
                action_name = ACTION_NAMES.preprocess_assemble,
                tools = [tool(path = tools_prefix + "clang")],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_module_compile,
                tools = [tool(path = tools_prefix + "clang++")],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_header_parsing,
                tools = [tool(path = tools_prefix + "clang++")],
            ),
            action_config(
                action_name = ACTION_NAMES.strip,
                tools = [tool(path = tools_prefix + "llvm-strip")],
            ),
        ]
        
        # tool_paths are still required for some tools
        tool_paths = [
            tool_path(name = "ar", path = tools_prefix + "llvm-ar"),
            tool_path(name = "cpp", path = tools_prefix + "clang++"),
            tool_path(name = "gcc", path = tools_prefix + "clang"),
            tool_path(name = "gcov", path = "/bin/false"),
            tool_path(name = "ld", path = tools_prefix + "wasm-ld"),
            tool_path(name = "nm", path = tools_prefix + "llvm-nm"),
            tool_path(name = "objcopy", path = tools_prefix + "llvm-objcopy"),
            tool_path(name = "objdump", path = tools_prefix + "llvm-objdump"),
            tool_path(name = "strip", path = tools_prefix + "llvm-strip"),
        ]
    else:
        # File label mode (for direct file references)
        clang_path = ctx.file.clang.path
        clang_pp_path = ctx.file.clang_pp.path
        wasm_ld_path = ctx.file.wasm_ld.path
        llvm_ar_path = ctx.file.llvm_ar.path
        llvm_nm_path = ctx.file.llvm_nm.path
        llvm_objcopy_path = ctx.file.llvm_objcopy.path
        llvm_objdump_path = ctx.file.llvm_objdump.path
        llvm_strip_path = ctx.file.llvm_strip.path
        
        # Create action configs with explicit tool paths
        # The tool path in action_config is relative to the execution root
        action_configs = [
            action_config(
                action_name = ACTION_NAMES.c_compile,
                tools = [tool(path = clang_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_compile,
                tools = [tool(path = clang_pp_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_link_executable,
                tools = [tool(path = clang_pp_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_link_dynamic_library,
                tools = [tool(path = clang_pp_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                tools = [tool(path = clang_pp_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.assemble,
                tools = [tool(path = clang_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.preprocess_assemble,
                tools = [tool(path = clang_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_module_compile,
                tools = [tool(path = clang_pp_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_header_parsing,
                tools = [tool(path = clang_pp_path)],
            ),
            action_config(
                action_name = ACTION_NAMES.strip,
                tools = [tool(path = llvm_strip_path)],
            ),
        ]
        
        # tool_paths are still required but won't be used since we have action_configs
        # We use dummy paths since they won't actually be used
        tool_paths = []
        
        # Get sysroot path - for flags we need execution root relative paths
        sysroot_path = ctx.file.sysroot_include.path.replace("/include/wasm32-wasi/stdint.h", "")
        lib_path = sysroot_path.replace("/share/wasi-sysroot", "") + "/lib"
    
    # Base compiler flags
    base_compiler_flags = [
        "-no-canonical-prefixes",
        "--target=wasm32-wasi",
        "-stdlib=libc++",
        "-fno-exceptions",  # Exceptions don't work in WASI
    ]
    
    rtti_flags = ["-fno-rtti"] if not ctx.attr.enable_rtti else []
    optimization_flags = ["-O" + ctx.attr.optimization_level]
    debug_flags = ["-g"] if ctx.attr.debug_info else []

    wasi_emulation_flags = []
    if ctx.attr.enable_wasi_emulated_mman:
        wasi_emulation_flags.append("-D_WASI_EMULATED_MMAN")
    if ctx.attr.enable_wasi_emulated_signal:
        wasi_emulation_flags.append("-D_WASI_EMULATED_SIGNAL")
    if ctx.attr.enable_wasi_emulated_process_clocks:
        wasi_emulation_flags.append("-D_WASI_EMULATED_PROCESS_CLOCKS")
    
    cxx_flags = (
        base_compiler_flags +
        rtti_flags +
        optimization_flags +
        debug_flags +
        wasi_emulation_flags +
        ["-DFMT_USE_FCNTL=0"] +
        ["-isystem", sysroot_path + "/include/wasm32-wasi/c++/v1"] +
        ["-isystem", sysroot_path + "/include/wasm32-wasi"] +
        ["-isystem", lib_path + "/clang/21/include"] +
        ctx.attr.additional_compiler_flags
    )
    
    linker_flags = [
        "-stdlib=libc++",
        "-lc++",
        "-lc++abi",
        "-lc",
        "-lm",
    ]
    
    if ctx.attr.enable_wasi_emulated_mman:
        linker_flags.append("-lwasi-emulated-mman")
    if ctx.attr.enable_wasi_emulated_signal:
        linker_flags.append("-lwasi-emulated-signal")
    if ctx.attr.enable_wasi_emulated_process_clocks:
        linker_flags.append("-lwasi-emulated-process-clocks")
    
    linker_flags.extend(ctx.attr.additional_linker_flags)

    default_flags_feature = feature(
        name = "default_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_header_parsing,
                ],
                flag_groups = [
                    flag_group(
                        flags = cxx_flags,
                    ),
                ],
            ),
             flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_executable,
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ],
                flag_groups = [
                    flag_group(
                        flags = linker_flags,
                    ),
                ],
            ),
        ],
    )

    sysroot_feature = feature(
        name = "sysroot",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_link_executable,
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ],
                flag_groups = [
                    flag_group(
                        flags = [
                            "--sysroot=" + sysroot_path,
                        ],
                    ),
                ],
            ),
        ],
    )
    
    unsupported_features = [
        feature(name = "coverage"),
        feature(name = "linking_mode"),
        feature(name = "random_seed"),
        feature(name = "fission"),
    ]
    
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        action_configs = action_configs,
        features = [sysroot_feature, default_flags_feature] + unsupported_features,
        cxx_builtin_include_directories = [
            sysroot_path + "/include/wasm32-wasi/c++/v1",
            sysroot_path + "/include/wasm32-wasi",
            lib_path + "/clang/21/include",
        ],
        toolchain_identifier = "wasm32-wasi",
        host_system_name = "local",
        target_system_name = "wasi",
        target_cpu = "wasm32",
        target_libc = "wasi",
        compiler = "clang",
        abi_version = "wasi",
        abi_libc_version = "wasi",
        tool_paths = tool_paths,
        builtin_sysroot = sysroot_path,
    )

wasm32_wasi_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        # File label attributes (for direct file references)
        "clang": attr.label(allow_single_file = True),
        "clang_pp": attr.label(allow_single_file = True),
        "wasm_ld": attr.label(allow_single_file = True),
        "llvm_ar": attr.label(allow_single_file = True),
        "llvm_nm": attr.label(allow_single_file = True),
        "llvm_objcopy": attr.label(allow_single_file = True),
        "llvm_objdump": attr.label(allow_single_file = True),
        "llvm_strip": attr.label(allow_single_file = True),
        "sysroot_include": attr.label(allow_single_file = True),
        
        # String path attributes (for symlinked tools)
        "tools_path_prefix": attr.string(
            default = "",
            doc = "Prefix for tool paths, relative to the package. If non-empty, string paths mode is used.",
        ),
        "sysroot_path": attr.string(
            default = "",
            doc = "Path to the sysroot, relative to the package. Used in string paths mode.",
        ),
        "lib_path": attr.string(
            default = "",
            doc = "Path to the lib directory (for clang headers), relative to the package. Used in string paths mode.",
        ),
        
        # Configuration options
        "enable_rtti": attr.bool(default = False),
        "optimization_level": attr.string(default = "2", values = ["0", "1", "2", "3", "s", "z"]),
        "debug_info": attr.bool(default = False),
        
        # WASI emulation options
        "enable_wasi_emulated_mman": attr.bool(default = True),
        "enable_wasi_emulated_signal": attr.bool(default = True),
        "enable_wasi_emulated_process_clocks": attr.bool(default = True),
        
        # Additional flags
        "additional_compiler_flags": attr.string_list(default = []),
        "additional_linker_flags": attr.string_list(default = []),
    },
    provides = [CcToolchainConfigInfo],
)

# Repository rule for setting up the WASM toolchain.
def _wasm_toolchain_repo_impl(rctx):
    """Implementation of the wasm_toolchain_repo repository rule."""
    
    # Get the path to the WASI SDK
    # The wasi_sdk label points to a file in the bin directory, so we need to go up twice
    # to get to the SDK root (bin/clang -> bin -> sdk_root)
    wasi_sdk_bin_path = rctx.path(rctx.attr.wasi_sdk).dirname
    wasi_sdk_path = wasi_sdk_bin_path.dirname
    
    # Tools that need to be symlinked from the WASI SDK
    tools = [
        "clang",
        "clang++",
        "wasm-ld",
        "llvm-ar",
        "llvm-nm",
        "llvm-objcopy",
        "llvm-objdump",
        "llvm-strip",
    ]
    
    # Create bin directory and symlink tools
    rctx.execute(["mkdir", "-p", "bin"])
    for tool_name in tools:
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
load("@wasm_toolchain//bazel:toolchain.bzl", "wasm32_wasi_toolchain_config")

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