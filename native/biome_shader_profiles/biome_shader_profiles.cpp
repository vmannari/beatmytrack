#include "biome_shader_profiles.h"
#include "core/object/class_db.h"
Mutex BMTShaderProfiles::mutex;
std::atomic<uint64_t> BMTShaderProfiles::generation{0};
bool BMTShaderProfiles::active = false, BMTShaderProfiles::selective = false;
String BMTShaderProfiles::phase, BMTShaderProfiles::context;
Dictionary BMTShaderProfiles::expected;
Array BMTShaderProfiles::observations;
uint64_t BMTShaderProfiles::dropped = 0, BMTShaderProfiles::skipped_defaults = 0;
uint64_t BMTShaderProfiles::compilation_count = 0, BMTShaderProfiles::compilation_us = 0, BMTShaderProfiles::late_compilation_us = 0;
std::map<uint32_t, BMTShaderProfiles::Program> BMTShaderProfiles::programs;
BMTShaderProfiles::Program *BMTShaderProfiles::current = nullptr;

void BMTShaderProfiles::_bind_methods() {
    ClassDB::bind_method(D_METHOD("revision"), &BMTShaderProfiles::revision);
    ClassDB::bind_method(D_METHOD("source_revision"), &BMTShaderProfiles::source_revision);
    ClassDB::bind_method(D_METHOD("begin", "scope", "entries", "selective"), &BMTShaderProfiles::begin);
    ClassDB::bind_method(D_METHOD("set_phase", "token", "phase"), &BMTShaderProfiles::set_phase);
    ClassDB::bind_method(D_METHOD("snapshot", "token"), &BMTShaderProfiles::snapshot);
    ClassDB::bind_method(D_METHOD("finish", "token"), &BMTShaderProfiles::finish);
    ClassDB::bind_method(D_METHOD("end", "token"), &BMTShaderProfiles::end);
}
bool BMTShaderProfiles::hex(const String &s, int length) {
    if (s.length() != length) return false;
    for (int i = 0; i < length; ++i) if (!((s[i] >= '0' && s[i] <= '9') || (s[i] >= 'a' && s[i] <= 'f'))) return false;
    return true;
}
String BMTShaderProfiles::key(const String &shader, int variant, uint64_t spec) {
    return (shader + ":" + itos(variant) + ":" + String::num_uint64(spec, 16)).sha256_text();
}
int64_t BMTShaderProfiles::begin(const String &scope, const Array &entries, bool enable_selective) {
    if (!hex(scope, 64) || entries.size() > 4096) return 0;
    Dictionary parsed;
    for (int i = 0; i < entries.size(); ++i) {
        if (entries[i].get_type() != Variant::DICTIONARY) return 0;
        Dictionary e = entries[i];
        if (e.size() != 3 || !e.has("shader") || !e.has("variant") || !e.has("specialization")) return 0;
        if (e["shader"].get_type() != Variant::STRING || e["specialization"].get_type() != Variant::STRING ||
            (e["variant"].get_type() != Variant::INT && e["variant"].get_type() != Variant::FLOAT)) return 0;
        String shader = e["shader"], spec = e["specialization"];
        double number = e["variant"];
        if (!(number >= 0 && number <= 255) || number != int(number)) return 0;
        int variant = e["variant"];
        if (!hex(shader, 64) || !hex(spec, 16) || variant < 0 || variant > 255) return 0;
        Array group = parsed.get(shader, Array());
        group.push_back(e.duplicate()); parsed[shader] = group;
    }
    MutexLock lock(mutex);
    if (active) return 0; // Another owner cannot replace a live race's scope.
    expected = parsed; context = scope; phase = "loading";
    observations.clear(); dropped = 0; skipped_defaults = 0;
    compilation_count = 0; compilation_us = 0; late_compilation_us = 0;
    selective = enable_selective && !parsed.is_empty(); active = true;
    return ++generation;
}
void BMTShaderProfiles::set_phase(int64_t token, const String &value) {
    if (value != "loading" && value != "countdown" && value != "driving" && value != "results") return;
    MutexLock lock(mutex);
    if (active && uint64_t(token) == generation.load()) phase = value;
}
Dictionary BMTShaderProfiles::snapshot(int64_t token) const {
    MutexLock lock(mutex);
    if (!active || uint64_t(token) != generation.load()) return Dictionary();
    return report_locked();
}
Dictionary BMTShaderProfiles::report_locked() {
    Dictionary out;
    out["context"] = context; out["selective"] = selective;
    out["observations"] = observations.duplicate(true);
    out["dropped"] = int64_t(dropped); out["skipped_defaults"] = int64_t(skipped_defaults);
    out["compilation_count"] = int64_t(compilation_count);
    out["compilation_us"] = int64_t(compilation_us);
    out["late_compilation_us"] = int64_t(late_compilation_us);
    return out;
}
Dictionary BMTShaderProfiles::finish(int64_t token) {
    MutexLock lock(mutex);
    if (!active || uint64_t(token) != generation.load()) return Dictionary();
    Dictionary out = report_locked();
    active = false; selective = false; expected.clear(); observations.clear(); ++generation;
    return out;
}
void BMTShaderProfiles::end(int64_t token) {
    MutexLock lock(mutex);
    if (active && uint64_t(token) == generation.load()) { active = false; selective = false; expected.clear(); observations.clear(); ++generation; }
}
bool BMTShaderProfiles::plan(const String &shader, Array &entries) {
    MutexLock lock(mutex);
    if (!active || !selective || !expected.has(shader)) return false;
    entries = expected[shader]; ++skipped_defaults; return true;
}
bool BMTShaderProfiles::known(const String &shader) {
    MutexLock lock(mutex);
    return active && selective && expected.has(shader);
}
void BMTShaderProfiles::compiled(uint32_t id, const String &shader, int variant, uint64_t spec, uint64_t us) {
    if (programs.size() >= 16384 && !programs.count(id)) {
        MutexLock lock(mutex); if (active) ++dropped; return;
    }
    MutexLock lock(mutex);
    Program &p = programs[id]; p = Program();
    p.shader = shader; p.variant = variant; p.specialization = spec; p.compile_us = us;
    p.compile_phase = active ? phase : String("outside"); p.compiled_scope = active ? generation.load() : 0;
    if (active && us > 0) {
        ++compilation_count; compilation_us += us;
        if (phase != "loading") late_compilation_us += us;
    }
}
void BMTShaderProfiles::bound(uint32_t id, const String &shader, int variant, uint64_t spec) {
    auto it = programs.find(id);
    if (it == programs.end()) { compiled(id, shader, variant, spec, 0); it = programs.find(id); }
    current = it == programs.end() ? nullptr : &it->second;
}
void BMTShaderProfiles::removed(uint32_t id) {
    auto it = programs.find(id);
    if (it != programs.end()) { if (current == &it->second) current = nullptr; programs.erase(it); }
}
void BMTShaderProfiles::draw() {
    if (!current || current->seen == generation.load()) return;
    MutexLock lock(mutex);
    current->seen = generation.load();
    if (!active) return;
    if (observations.size() >= 4096) { ++dropped; return; }
    bool listed = false;
    Array group = expected.get(current->shader, Array());
    for (int i = 0; i < group.size(); ++i) {
        Dictionary e = group[i];
        if (int(e["variant"]) == current->variant && String(e["specialization"]).hex_to_int() == int64_t(current->specialization)) { listed = true; break; }
    }
    Dictionary event;
    event["shader"] = current->shader; event["variant"] = current->variant;
    event["specialization"] = String::num_uint64(current->specialization, 16).lpad(16, "0");
    event["key"] = key(current->shader, current->variant, current->specialization);
    const bool late = current->compiled_scope == generation.load() && current->compile_us > 0 && current->compile_phase != "loading";
    event["phase"] = phase; event["listed"] = listed; event["missing"] = !listed || late;
    event["compile_us"] = current->compiled_scope == generation.load() ? int64_t(current->compile_us) : 0;
    event["compile_phase"] = current->compiled_scope == generation.load() ? current->compile_phase : String("cached");
    observations.push_back(event);
}
