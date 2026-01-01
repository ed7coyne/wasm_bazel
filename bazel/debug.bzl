def _debug_impl(ctx):
    print("clang.path:", ctx.file.clang.path)
    print("clang.short_path:", ctx.file.clang.short_path)
    print("clang.root.path:", ctx.file.clang.root.path)
    return []

debug_rule = rule(
    implementation = _debug_impl,
    attrs = {
        "clang": attr.label(allow_single_file = True),
    },
)
