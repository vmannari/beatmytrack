#pragma once
#include "biome_shader_profiles.h"
#include <platform_gl.h>
// Arguments are evaluated exactly once; empty draws do not certify coverage.
inline void bmt_profile_glDrawArrays(GLenum mode, GLint first, GLsizei count) {
    if (count > 0) BMTShaderProfiles::draw();
    glDrawArrays(mode, first, count);
}
inline void bmt_profile_glDrawArraysInstanced(GLenum mode, GLint first, GLsizei count, GLsizei instances) {
    if (count > 0 && instances > 0) BMTShaderProfiles::draw();
    glDrawArraysInstanced(mode, first, count, instances);
}
inline void bmt_profile_glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices) {
    if (count > 0) BMTShaderProfiles::draw();
    glDrawElements(mode, count, type, indices);
}
inline void bmt_profile_glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instances) {
    if (count > 0 && instances > 0) BMTShaderProfiles::draw();
    glDrawElementsInstanced(mode, count, type, indices, instances);
}
