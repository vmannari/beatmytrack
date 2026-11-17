// Original local geometry/compiler kernels and optional exact tyre contacts.
#include <godot_cpp/classes/class_db_singleton.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <set>
using namespace godot;
#include "tyre_contacts.hpp"

namespace {
enum Stream { VERTEX = 0, NORMAL = 1, COLOR = 3, UV = 4, UV2 = 5, INDEX = 12 };
struct Vertex {
    Vector3 point, normal;
    Vector2 uv, uv2;
    Color color;
    Vertex middle(const Vertex &other) const {
        return {point.lerp(other.point, 0.5f), normal.lerp(other.normal, 0.5f),
                uv.lerp(other.uv, 0.5f), uv2.lerp(other.uv2, 0.5f), color.lerp(other.color, 0.5f)};
    }
};

struct Relief {
    PackedFloat32Array field;
    int64_t width = 0, rows = 0;
    double cell_size = 0.5;
    Vector2 half_extent;
    Rect2 bounds;
    Transform3D inverse;
    Basis normal_to_local;
    Callable cancellation;
    uint64_t visited = 0;
    bool aborted = false;
    Object *tool = nullptr;

    bool cancelled() {
        // Keep cancellation bounded without crossing the script boundary for
        // every vertex. Each job owns its own arrays and SurfaceTool instance.
        if ((visited++ & 127) == 0 && cancellation.is_valid()) {
            aborted = bool(cancellation.call());
        }
        return aborted;
    }
    double cell(int x, int y) const {
        if (x < 0 || y < 0 || x >= width || y >= rows) return 0.0;
        return field[int64_t(y) * width + x];
    }
    static double lerp(double a, double b, double weight) { return a + (b - a) * weight; }
    double height(const Vector2 &point) const {
        // Match GDScript scalar double arithmetic and Vector2 float boundaries.
        Vector2 coordinate(float((double(point.x) + half_extent.x) / cell_size),
                           float((double(half_extent.y) - point.y) / cell_size));
        coordinate -= Vector2(0.5f, 0.5f);
        int x = int(std::floor(coordinate.x)), y = int(std::floor(coordinate.y));
        double fx = double(coordinate.x) - x, fy = double(coordinate.y) - y;
        return lerp(lerp(cell(x,y),cell(x+1,y),fx),lerp(cell(x,y+1),cell(x+1,y+1),fx),fy);
    }
    Vector3 sample(const Vector2 &point) const {
        double step = cell_size * 0.25;
        return Vector3(float((height(point+Vector2(float(step),0))-height(point-Vector2(float(step),0)))/(step*2.0)),
                       float(height(point)),
                       float((height(point+Vector2(0,float(-step)))-height(point+Vector2(0,float(step))))/(step*2.0)));
    }
    void emit(const Vertex &vertex) {
        Vector3 point = vertex.point, normal = vertex.normal;
        Vector3 relief = sample(Vector2(point.x,-point.z));
        point.y = float(double(point.y) + relief.y);
        normal = Vector3(float(double(normal.x)-double(relief.x)*normal.y), normal.y,
                         float(double(normal.z)-double(relief.z)*normal.y)).normalized();
        tool->call("set_normal",normal_to_local.xform(normal).normalized());
        tool->call("set_uv",vertex.uv);
        tool->call("set_uv2",vertex.uv2);
        tool->call("set_color",vertex.color);
        tool->call("add_vertex",inverse.xform(point));
    }
    void triangle(const std::array<Vertex,3> &vertices, bool refine, int depth) {
        if (cancelled()) return;
        const Vector3 &a = vertices[0].point, &b = vertices[1].point, &c = vertices[2].point;
        double lengths[3] = {
            Vector2(a.x-b.x,a.z-b.z).length_squared(),
            Vector2(b.x-c.x,b.z-c.z).length_squared(),
            Vector2(c.x-a.x,c.z-a.z).length_squared()
        };
        int longest = 0;
        if (lengths[1] > lengths[longest]) longest = 1;
        if (lengths[2] > lengths[longest]) longest = 2;
        if (refine && depth < 28 && lengths[longest] > 1.0) {
            Rect2 rectangle(Vector2(a.x,-a.z),Vector2());
            rectangle.expand_to(Vector2(b.x,-b.z)); rectangle.expand_to(Vector2(c.x,-c.z));
            if (rectangle.intersects(bounds,true)) {
                std::array<Vector3,7> samples = {a,b,c,(a+b)*0.5f,(b+c)*0.5f,(c+a)*0.5f,(a+b+c)/3.0f};
                double first = height(Vector2(samples[0].x,-samples[0].z));
                bool uniform = true;
                for (size_t i=1;i<samples.size();++i) {
                    if (height(Vector2(samples[i].x,-samples[i].z)) != first) {uniform=false;break;}
                }
                if (!uniform || lengths[longest] > 16.0) {
                    int next = (longest+1)%3, other = (longest+2)%3;
                    Vertex middle = vertices[longest].middle(vertices[next]);
                    triangle({vertices[longest],middle,vertices[other]},refine,depth+1);
                    triangle({middle,vertices[next],vertices[other]},refine,depth+1);
                    return;
                }
            }
        }
        for (const Vertex &vertex : vertices) emit(vertex);
    }
};
}

#include "road_geometry.hpp"
#include "editor_streams.hpp"
#include "raster_geometry.hpp"
#include "winter_geometry.hpp"
#include "checkpoint_geometry.hpp"
#include "asphalt_sides.hpp"

class BmtTrackGeometry : public RefCounted {
    GDCLASS(BmtTrackGeometry,RefCounted)
    checkpoint_geometry::Route checkpoint_route;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("relief","streams","terrain","transform","refine","cancelled"),&BmtTrackGeometry::relief);
        ClassDB::bind_method(D_METHOD("algorithm_version"),&BmtTrackGeometry::algorithm_version);
        ClassDB::bind_method(D_METHOD("road_algorithm_version"),&BmtTrackGeometry::road_algorithm_version);
        ClassDB::bind_method(D_METHOD("road_asphalt_sides","tool","ends","outwards","bottom"),&BmtTrackGeometry::road_asphalt_sides);
        ClassDB::bind_method(D_METHOD("winter_algorithm_version"),&BmtTrackGeometry::winter_algorithm_version);
        ClassDB::bind_method(D_METHOD("raster_algorithm_version"),&BmtTrackGeometry::raster_algorithm_version);
        ClassDB::bind_method(D_METHOD("checkpoint_algorithm_version"),&BmtTrackGeometry::checkpoint_algorithm_version);
        ClassDB::bind_method(D_METHOD("checkpoint_crossings","centers","directions","widths","path"),&BmtTrackGeometry::checkpoint_crossings);
        ClassDB::bind_method(D_METHOD("checkpoint_prepare","route","cumulative"),&BmtTrackGeometry::checkpoint_prepare);
        ClassDB::bind_method(D_METHOD("checkpoint_projection","point"),&BmtTrackGeometry::checkpoint_projection);
        ClassDB::bind_method(D_METHOD("checkpoint_lane","route","basis","fraction","constant_width","rejoin_start","recovery","geometry"),&BmtTrackGeometry::checkpoint_lane);
        ClassDB::bind_method(D_METHOD("winter_row","anchor","outward","points","cache","drift","pack"),&BmtTrackGeometry::winter_row);
        ClassDB::bind_method(D_METHOD("winter_section","tool","anchors","points","cache","drift","pack"),&BmtTrackGeometry::winter_section);
        ClassDB::bind_method(D_METHOD("winter_markers","triangles","route","bridges","cancelled"),&BmtTrackGeometry::winter_markers);
        ClassDB::bind_method(D_METHOD("raster_road","data","geometry","cancelled"),&BmtTrackGeometry::raster_road);
        ClassDB::bind_method(D_METHOD("raster_paint","strokes","data","geometry","cancelled"),&BmtTrackGeometry::raster_paint);
        ClassDB::bind_method(D_METHOD("raster_pixels","cells","excluded","overlay"),&BmtTrackGeometry::raster_pixels);
        ClassDB::bind_method(D_METHOD("road_collect","triangles","grass","geometry","cancelled"),&BmtTrackGeometry::road_collect);
        ClassDB::bind_method(D_METHOD("road_shoulder","triangles","geometry","tool","cancelled"),&BmtTrackGeometry::road_shoulder);
        ClassDB::bind_method(D_METHOD("road_emit","triangles","paths","settings","blend","theme","mode","height","geometry","tool","cancelled"),&BmtTrackGeometry::road_emit);
        ClassDB::bind_method(D_METHOD("road_finish","arrays","flags","cancelled"),&BmtTrackGeometry::road_finish);
        ClassDB::bind_method(D_METHOD("road_unpack","arrays","normals"),&BmtTrackGeometry::road_unpack);
        ClassDB::bind_method(D_METHOD("editor_split","arrays","tile_size"),&BmtTrackGeometry::editor_split);
        ClassDB::bind_method(D_METHOD("editor_append","tool","arrays"),&BmtTrackGeometry::editor_append);
        ClassDB::bind_method(D_METHOD("road_edges","contours","cuts","outlines","joined","index","swept","winter","geometry","cancelled"),&BmtTrackGeometry::road_edges);
        ClassDB::bind_method(D_METHOD("road_polygon","polygon","points","settings","blend","theme","height","geometry","tool","cancelled"),&BmtTrackGeometry::road_polygon);
    }
public:
    int64_t algorithm_version() const { return 1; }
    int64_t road_algorithm_version() const { return 1; }
    bool road_asphalt_sides(Object *tool,const PackedVector3Array &ends,const PackedVector3Array &outwards,double bottom) const {return asphalt_sides::emit(tool,ends,outwards,bottom);}
    int64_t winter_algorithm_version() const { return 1; }
    int64_t raster_algorithm_version() const { return 1; }
    int64_t checkpoint_algorithm_version() const { return 1; }
    PackedFloat64Array checkpoint_crossings(const PackedVector2Array &centers,const PackedVector2Array &directions,const PackedVector2Array &widths,const PackedVector2Array &path) const {return checkpoint_geometry::crossings(centers,directions,widths,path);}
    bool checkpoint_prepare(const PackedVector2Array &route,const PackedFloat64Array &cumulative) {return checkpoint_route.prepare(route,cumulative);}
    double checkpoint_projection(Vector2 point) const {return checkpoint_route.projection(point);}
    PackedVector2Array checkpoint_lane(const PackedVector2Array &route,const Dictionary &basis,double fraction,bool constant_width,bool rejoin_start,double recovery,Object *geometry) const {return checkpoint_geometry::lane(route,basis,fraction,constant_width,rejoin_start,recovery,geometry);}
    Dictionary winter_row(Vector2 anchor,Vector2 outward,const PackedVector2Array &points,Dictionary cache,Object *drift,Object *pack) const {return winter_geometry::row(anchor,outward,points,cache,drift,pack);}
    bool winter_section(Object *tool,const PackedVector2Array &anchors,const PackedVector2Array &points,Dictionary cache,Object *drift,Object *pack) const {return winter_geometry::section(tool,anchors,points,cache,drift,pack);}
    Dictionary winter_markers(const Array &triangles,const PackedVector2Array &route,const Array &bridges,const Callable &cancelled) const {return winter_geometry::markers(triangles,route,bridges,cancelled);}
    Dictionary raster_road(const Dictionary &data,Object *geometry,const Callable &cancelled) const {return raster_geometry::road(data,geometry,cancelled);}
    Dictionary raster_paint(const Array &strokes,const Dictionary &data,Object *geometry,const Callable &cancelled) const {return raster_geometry::paint(strokes,data,geometry,cancelled);}
    PackedByteArray raster_pixels(const PackedInt32Array &cells,const PackedByteArray &excluded,bool overlay) const {return raster_geometry::pixels(cells,excluded,overlay);}
    Dictionary road_collect(const Array &triangles,bool grass,Object *geometry,const Callable &cancelled) const {
        return road_geometry::collect(triangles,grass,geometry,cancelled);
    }
    Dictionary road_shoulder(const Array &triangles,Object *geometry,Object *tool,const Callable &cancelled) const {
        Dictionary result=road_geometry::collect(triangles,false,geometry,cancelled);
        if (result.is_empty() || !tool) return {};
        PackedVector2Array points=result["points"],uv=result["uv"];
        road_geometry::Stop stop{cancelled};
        for (int64_t i=0;i<points.size();++i) {
            if (stop.check()) return {};
            road_geometry::set_uv(tool,uv[i]);road_geometry::add_vertex(tool,road_geometry::world(points[i])+Vector3(0,-0.02f,0));
        }
        return road_geometry::result("count",points.size()/3);
    }
    Dictionary road_emit(const Array &triangles,const Array &paths,const Array &settings,const Dictionary &blend,const String &theme,int64_t mode,double height,Object *geometry,Object *tool,const Callable &cancelled) const {
        return road_geometry::emit(triangles,paths,settings,blend,theme,int(mode),height,geometry,tool,cancelled);
    }
    Array road_finish(const Array &arrays,const Dictionary &flags,const Callable &cancelled) const { return road_geometry::finish(arrays,flags,cancelled); }
    Array road_unpack(const Array &arrays,bool normals) const { return road_geometry::unpack(arrays,normals); }
    Array editor_split(const Array &arrays,double tile_size) const {return editor_streams::split(arrays,tile_size);}
    bool editor_append(Object *tool,const Array &arrays) const {return editor_streams::append(tool,arrays);}
    Dictionary road_edges(const Array &contours,const Array &cuts,const Array &outlines,const Array &joined,int64_t index,bool swept,bool winter,Object *geometry,const Callable &cancelled) const {
        return road_geometry::edge_samples(contours,cuts,outlines,joined,int(index),swept,winter,geometry,cancelled);
    }
    Dictionary road_polygon(const PackedVector2Array &polygon,const PackedVector2Array &points,const Dictionary &settings,const Dictionary &blend,const String &theme,double height,Object *geometry,Object *tool,const Callable &cancelled) const {
        if (!geometry || !tool) return {};
        road_geometry::Stop stop{cancelled};
        road_geometry::Emitter work;work.geometry=geometry;work.tool=tool;work.stop=&stop;work.theme=theme;work.height=height;
        work.blending.geometry=geometry;work.blending.load(blend);
        int count=work.polygon(polygon,points,settings);
        return stop.aborted?Dictionary():road_geometry::result("count",count);
    }
    Array relief(const Array &streams, const Dictionary &terrain, const Transform3D &transform, bool refine, const Callable &cancelled) const {
        Relief work;
        work.field = terrain.get("field",PackedFloat32Array());
        work.width = terrain.get("width",0); work.rows = terrain.get("rows",0);
        work.cell_size = terrain.get("cell_size",0.0);
        work.half_extent = terrain.get("half_extent",Vector2());
        work.bounds = terrain.get("bounds",Rect2()); work.cancellation = cancelled;
        if (work.width<=0 || work.rows<=0 || work.width>work.field.size() || work.rows>work.field.size() || work.width>std::numeric_limits<int>::max() || work.rows>std::numeric_limits<int>::max() || work.width*work.rows!=work.field.size() || work.cell_size<=0 || !std::isfinite(work.cell_size)) return Array();
        work.inverse = transform.affine_inverse();
        work.normal_to_local = work.inverse.basis.inverse().transposed();
        Basis normal_to_world = transform.basis.inverse().transposed();
        Array result;
        for (int64_t surface=0;surface<streams.size();++surface) {
            if (work.cancelled()) return Array();
            Array arrays = streams[surface];
            if (arrays.size()<=INDEX || arrays[VERTEX].get_type()!=Variant::PACKED_VECTOR3_ARRAY) return Array();
            PackedVector3Array positions=arrays[VERTEX], normals;
            PackedVector2Array uv,uv2; PackedColorArray colors; PackedInt32Array indices;
            if (arrays[NORMAL].get_type()==Variant::PACKED_VECTOR3_ARRAY) normals=arrays[NORMAL];
            if (arrays[UV].get_type()==Variant::PACKED_VECTOR2_ARRAY) uv=arrays[UV];
            if (arrays[UV2].get_type()==Variant::PACKED_VECTOR2_ARRAY) uv2=arrays[UV2];
            if (arrays[COLOR].get_type()==Variant::PACKED_COLOR_ARRAY) colors=arrays[COLOR];
            if (arrays[INDEX].get_type()==Variant::PACKED_INT32_ARRAY) indices=arrays[INDEX];
            int64_t count=indices.is_empty()?positions.size():indices.size();
            if (count%3 || (!normals.is_empty()&&normals.size()!=positions.size()) || (!uv.is_empty()&&uv.size()!=positions.size()) || (!uv2.is_empty()&&uv2.size()!=positions.size()) || (!colors.is_empty()&&colors.size()!=positions.size())) return Array();
            Variant tool_reference = ClassDBSingleton::get_singleton()->instantiate("SurfaceTool");
            work.tool = tool_reference;
            if (!work.tool) return Array();
            work.tool->call("begin",4); // Mesh.PRIMITIVE_TRIANGLES
            for (int64_t first=0;first<count;first+=3) {
                if (work.cancelled()) return Array();
                std::array<Vertex,3> triangle;
                for (int j=0;j<3;++j) {
                    int64_t index=indices.is_empty()?first+j:indices[first+j];
                    if (index<0 || index>=positions.size()) return Array();
                    triangle[j]={transform.xform(positions[index]),normals.is_empty()?Vector3(0,1,0):normal_to_world.xform(normals[index]),
                                 uv.is_empty()?Vector2():uv[index],uv2.is_empty()?Vector2():uv2[index],colors.is_empty()?Color(1,1,1,1):colors[index]};
                }
                work.triangle(triangle,refine,0);
                if (work.aborted) return Array();
            }
            if (work.cancelled()) return Array();
            work.tool->call("index");
            if (work.cancelled()) return Array();
            result.push_back(work.tool->call("commit_to_arrays"));
        }
        return result;
    }
};

static void initialize(ModuleInitializationLevel level) {
    if (level==MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_class<BmtTrackGeometry>();
        ClassDB::register_class<BmtTyreContacts>();
    }
}
static void uninitialize(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT bmt_track_geometry_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(address,library,initialization);
    init.register_initializer(initialize); init.register_terminator(uninitialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
