// Small typed bindings to the pinned engine APIs, following godot-cpp's ptrcall
// convention. Method hashes come from the existing pinned extension_api.json.
#include <godot_cpp/core/engine_ptrcall.hpp>
namespace road_geometry {
inline GDExtensionMethodBindPtr binding(const char *type,const char *method,uint64_t hash) {
    return internal::gdextension_interface_classdb_get_method_bind(StringName(type)._native_ptr(),StringName(method)._native_ptr(),hash);
}
inline Array intersections(Object *geometry,const PackedVector2Array &a,const PackedVector2Array &b) {
    static auto method=binding("Geometry2D","intersect_polygons",3637387053);
    return internal::_call_native_mb_ret<Array>(method,geometry->_owner,&a,&b);
}
inline PackedInt32Array triangulate(Object *geometry,const PackedVector2Array &polygon) {
    static auto method=binding("Geometry2D","triangulate_polygon",1389921771);
    return internal::_call_native_mb_ret<PackedInt32Array>(method,geometry->_owner,&polygon);
}
inline Vector2 closest(Object *geometry,const Vector2 &point,const Vector2 &a,const Vector2 &b) {
    static auto method=binding("Geometry2D","get_closest_point_to_segment",4172901909);
    return internal::_call_native_mb_ret<Vector2>(method,geometry->_owner,&point,&a,&b);
}
inline bool contains(Object *geometry,const Vector2 &point,const PackedVector2Array &polygon) {
    static auto method=binding("Geometry2D","is_point_in_polygon",738277916);
    return internal::_call_native_mb_ret<int8_t>(method,geometry->_owner,&point,&polygon);
}
inline bool clockwise(Object *geometry,const PackedVector2Array &polygon) {
    static auto method=binding("Geometry2D","is_polygon_clockwise",1361156557);
    return internal::_call_native_mb_ret<int8_t>(method,geometry->_owner,&polygon);
}
inline void add_vertex(Object *tool,const Vector3 &value) {
    static auto method=binding("SurfaceTool","add_vertex",3460891852);
    internal::_call_native_mb_no_ret(method,tool->_owner,&value);
}
inline void set_normal(Object *tool,const Vector3 &value) {
    static auto method=binding("SurfaceTool","set_normal",3460891852);
    internal::_call_native_mb_no_ret(method,tool->_owner,&value);
}
inline void set_uv(Object *tool,const Vector2 &value) {
    static auto method=binding("SurfaceTool","set_uv",743155724);
    internal::_call_native_mb_no_ret(method,tool->_owner,&value);
}
inline void set_uv2(Object *tool,const Vector2 &value) {
    static auto method=binding("SurfaceTool","set_uv2",743155724);
    internal::_call_native_mb_no_ret(method,tool->_owner,&value);
}
inline void set_color(Object *tool,const Color &value) {
    static auto method=binding("SurfaceTool","set_color",2920490490);
    internal::_call_native_mb_no_ret(method,tool->_owner,&value);
}
}
