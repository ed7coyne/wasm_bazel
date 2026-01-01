# bazel/toolchain_config.bzl
"""WASM toolchain configuration for Bazel.

This module provides a cc_toolchain_config rule that configures a WASM/WASI
toolchain using string paths (for use with symlinked tools).
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
    
    # Tool paths are relative to the package where cc_toolchain is defined
    # Since we symlink tools into bin/, we use simple relative paths
    tools_prefix = ctx.attr.tools_path_prefix
    sysroot = ctx.attr.sysroot_path
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
        ["-isystem", sysroot + "/include/wasm32-wasi/c++/v1"] +
        ["-isystem", sysroot + "/include/wasm32-wasi"] +
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
                            "--sysroot=" + sysroot,
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
            sysroot + "/include/wasm32-wasi/c++/v1",
            sysroot + "/include/wasm32-wasi",
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
        builtin_sysroot = sysroot,
    )

wasm32_wasi_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        # Path configuration (relative to the package)
        "tools_path_prefix": attr.string(
            default = "bin/",
            doc = "Prefix for tool paths, relative to the package",
        ),
        "sysroot_path": attr.string(
            default = "sysroot",
            doc = "Path to the sysroot, relative to the package",
        ),
        "lib_path": attr.string(
            default = "lib",
            doc = "Path to the lib directory (for clang headers), relative to the package",
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
