#include "register_types.h"
#include "biome_shader_profiles.h"
#include "core/config/engine.h"
#include "core/object/class_db.h"
static BMTShaderProfiles *instance = nullptr;
void initialize_biome_shader_profiles_module(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    GDREGISTER_CLASS(BMTShaderProfiles);
    instance = memnew(BMTShaderProfiles);
    Engine::get_singleton()->add_singleton(Engine::Singleton("BMTShaderProfiles", instance));
}
void uninitialize_biome_shader_profiles_module(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    Engine::get_singleton()->remove_singleton("BMTShaderProfiles");
    memdelete(instance); instance = nullptr;
}
