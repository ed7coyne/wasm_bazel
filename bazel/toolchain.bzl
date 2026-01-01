# bazel/toolchain.bzl
load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "feature", "flag_group", "flag_set", "tool_path")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _impl(ctx):
    tool_paths = [
        tool_path(name = "gcc", path = ctx.file.clang.path),
        tool_path(name = "g++", path = ctx.file.clang_pp.path),
        tool_path(name = "ld", path = ctx.file.wasm_ld.path),
        tool_path(name = "ar", path = ctx.file.llvm_ar.path),
        tool_path(name = "nm", path = ctx.file.llvm_nm.path),
        tool_path(name = "objcopy", path = ctx.file.llvm_objcopy.path),
        tool_path(name = "objdump", path = ctx.file.llvm_objdump.path),
        tool_path(name = "strip", path = ctx.file.llvm_strip.path),
        tool_path(name = "cpp", path = ctx.file.clang.path), 
    ]
    
    # Get sysroot path from the sysroot_include file
    sysroot_path = ctx.file.sysroot_include.path.replace("/include/wasm32-wasi/stdint.h", "")
    repo_root = sysroot_path.replace("/share/wasi-sysroot", "")
    
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
        ["-isystem", repo_root + "/lib/clang/21/include"] +
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
        features = [sysroot_feature, default_flags_feature] + unsupported_features,
        cxx_builtin_include_directories = [
            sysroot_path + "/include/wasm32-wasi/c++/v1",
            sysroot_path + "/include/wasm32-wasi",
            repo_root + "/lib/clang/21/include",
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
        "clang": attr.label(allow_single_file = True),
        "clang_pp": attr.label(allow_single_file = True),
        "wasm_ld": attr.label(allow_single_file = True),
        "llvm_ar": attr.label(allow_single_file = True),
        "llvm_nm": attr.label(allow_single_file = True),
        "llvm_objcopy": attr.label(allow_single_file = True),
        "llvm_objdump": attr.label(allow_single_file = True),
        "llvm_strip": attr.label(allow_single_file = True),
        "sysroot_include": attr.label(allow_single_file = True),
        
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