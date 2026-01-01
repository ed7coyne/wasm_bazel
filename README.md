# WASM Toolchain for Bazel

This repository provides a reusable WebAssembly (WASM) toolchain for Bazel projects. It allows you to easily compile C/C++ code to WebAssembly using the WASI SDK and run it with various WASM runtimes.

## Features

- Complete WASM toolchain based on WASI SDK
- Platform transition rules for easy WASM compilation
- Support for running WASM binaries with Wasmer or Wasmtime
- Configurable optimization levels and compiler flags
- Utility for testing WASM modules

## Getting Started

### Adding the Toolchain to Your Project

Add the following to your `MODULE.bazel` file:

```python
bazel_dep(name = "wasm_toolchain", version = "0.1.0")
```

### Building a WASM Binary

Create a C/C++ source file:

```cpp
// hello.cc
#include <stdio.h>
#include <string>

int main(int argc, char** argv) {
    std::string name = "World";
    if (argc > 1) {
        name = argv[1];
    }
    printf("Hello %s!\n", name.c_str());
    return 0;
}
```

Create a BUILD file:

```python
load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@wasm_toolchain//bazel:transitions.bzl", "wasm_binary", "wasm_run")

cc_binary(
    name = "hello_bin",
    srcs = ["hello.cc"],
    target_compatible_with = [
        "@platforms//os:wasi",
        "@platforms//cpu:wasm32",
    ],
)

wasm_binary(
    name = "hello_wasm",
    binary = ":hello_bin",
)

wasm_run(
    name = "hello",
    binary = ":hello_bin",
    runner = "@wasmer//:wasmer",
)
```

### Building and Running

Build the WASM binary:

```bash
bazel build //path/to:hello_wasm
```

Run the WASM binary:

```bash
bazel run //path/to:hello
```

## Toolchain Configuration

The toolchain can be configured with various options:

```python
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
    
    # Configuration options
    enable_rtti = False,
    optimization_level = "2",  # 0, 1, 2, 3, s, z
    debug_info = False,
    
    # WASI emulation options
    enable_wasi_emulated_mman = True,
    enable_wasi_emulated_signal = True,
    enable_wasi_emulated_process_clocks = True,
    
    # Additional flags
    additional_compiler_flags = [],
    additional_linker_flags = [],
)
```

## Examples

See the [examples](examples/) directory for complete examples of using the toolchain.

## License

This project is licensed under the Apache License, Version 2.0 - see the LICENSE file for details.