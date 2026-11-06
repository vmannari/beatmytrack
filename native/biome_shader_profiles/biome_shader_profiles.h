#pragma once
#include "core/object/ref_counted.h"
#include "core/os/mutex.h"
#include "core/variant/typed_array.h"
#include <atomic>
#include <map>
#include "build_fingerprint.gen.h"

// Engine-owned GLES3 instrumentation. No GL interception or driver replacement.
class BMTShaderProfiles : public Object {
    GDCLASS(BMTShaderProfiles, Object);
    struct Program {
        String shader;
        int variant = 0;
        uint64_t specialization = 0, compile_us = 0, seen = 0;
        String compile_phase;
        uint64_t compiled_scope = 0;
    };
    static Mutex mutex;
    static std::atomic<uint64_t> generation;
    static bool active, selective;
    static String phase, context;
    static Dictionary expected;
    static Array observations;
    static uint64_t dropped, skipped_defaults;
    static uint64_t compilation_count, compilation_us, late_compilation_us;
    // Render-thread-only program registry/current binding; the main thread
    // changes only scoped configuration under mutex. No GPU handles persist.
    static std::map<uint32_t, Program> programs;
    static Program *current;
    static bool hex(const String &value, int length);
    static Dictionary report_locked();
protected:
    static void _bind_methods();
public:
    String revision() const { return "bmt-biome-gles3-1"; }
    String source_revision() const { return BMT_SHADER_PROFILE_SOURCE; }
    int64_t begin(const String &scope, const Array &entries, bool enable_selective);
    void set_phase(int64_t token, const String &value);
    Dictionary snapshot(int64_t token) const;
    Dictionary finish(int64_t token);
    void end(int64_t token);
    static String key(const String &shader, int variant, uint64_t specialization);
    static bool plan(const String &shader, Array &entries);
    static bool known(const String &shader);
    static void compiled(uint32_t id, const String &shader, int variant, uint64_t specialization, uint64_t microseconds);
    static void bound(uint32_t id, const String &shader, int variant, uint64_t specialization);
    static void removed(uint32_t id);
    static void draw();
};
