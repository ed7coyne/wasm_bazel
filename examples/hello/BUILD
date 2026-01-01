load("@rules_cc//cc:defs.bzl", "cc_binary")
load("//bazel:transitions.bzl", "wasm_binary", "wasm_run")

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