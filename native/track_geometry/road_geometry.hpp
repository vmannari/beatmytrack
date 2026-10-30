// Original ports of the client road presentation kernels. See PROVENANCE.md.
#include <godot_cpp/variant/packed_float64_array.hpp>
#include "road_engine_api.hpp"
#include <map>
#include <set>
#include <vector>

namespace road_geometry {
using Polygon = PackedVector2Array;
inline Dictionary result(const char *key,const Variant &value) {Dictionary data;data[key]=value;return data;}
struct Stop {
    Callable callback;
    uint64_t steps = 0;
    bool aborted = false;
    bool check() {
        if ((steps++ & 127) == 0 && callback.is_valid()) aborted = bool(callback.call());
        return aborted;
    }
};
struct Triangle {
    Polygon polygon;
    Vector2 gradient, height_gradient;
    double offset = 0, height_offset = 0;
    bool has_height = false;
    Rect2 bounds;
};
inline double clamp(double x, double lo, double hi) { return std::max(lo,std::min(hi,x)); }
inline Vector3 world(Vector2 p) { return Vector3(p.x,0,-p.y); }
inline Polygon lower_half(const Polygon &polygon, Vector2 gradient, double offset) {
    Polygon result;
    for (int64_t i=0;i<polygon.size();++i) {
        Vector2 a=polygon[i],b=polygon[(i+1)%polygon.size()];
        double da=double(gradient.dot(a))+offset,db=double(gradient.dot(b))+offset;
        if (da<=0) result.append(a);
        if ((da<0 && db>0)||(da>0 && db<0)) result.append(a.lerp(b,float(da/(da-db))));
    }
    return result;
}
inline std::vector<Polygon> subtract(const Polygon &source,const Polygon &cutter,Object *geometry) {
    Array intersection=intersections(geometry,source,cutter);
    if (intersection.is_empty()) return {source};
    double area=0;
    for (int64_t i=1;i<cutter.size()-1;++i) {
        Vector2 u=cutter[i]-cutter[0],v=cutter[i+1]-cutter[0];
        area+=double(u.x)*v.y-double(u.y)*v.x;
    }
    if (area==0) return {source};
    Polygon inside=source;
    std::vector<Polygon> result;
    for (int64_t i=0;i<cutter.size();++i) {
        Vector2 a=cutter[i],edge=cutter[(i+1)%cutter.size()]-a;
        if (edge.length_squared()<0.00000001) continue;
        Vector2 normal=Vector2(-edge.y,edge.x).normalized();
        if (area>0) normal=-normal;
        Polygon outside=lower_half(inside,-normal,normal.dot(a));
        if (outside.size()>=3) result.push_back(outside);
        inside=lower_half(inside,normal,-normal.dot(a));
        if (inside.size()<3) break;
    }
    return result;
}
struct Clip {
    std::vector<Triangle> triangles;
    std::map<std::pair<int,int>,std::vector<int>> bins;
    std::map<std::array<int,4>,std::vector<int>> candidates;
    Object *geometry;
    Stop *stop;
    bool load(const Array &input) {
        if (input.size()>2000000) return false;
        triangles.reserve(input.size());
        for (int64_t i=0;i<input.size();++i) {
            if (stop->check() || input[i].get_type()!=Variant::DICTIONARY) return false;
            Dictionary data=input[i];
            if (data.get("polygon",Variant()).get_type()!=Variant::PACKED_VECTOR2_ARRAY) return false;
            Triangle t;
            t.polygon=data["polygon"];
            if (t.polygon.size()!=3) return false;
            t.gradient=data.get("gradient",Vector2()); t.offset=data.get("offset",0.0);
            t.bounds=data.get("bounds",Rect2());
            t.has_height=data.has("height_gradient");
            t.height_gradient=data.get("height_gradient",Vector2()); t.height_offset=data.get("height_offset",0.0);
            if (!t.bounds.position.is_finite() || !t.bounds.size.is_finite() || !t.gradient.is_finite() || !std::isfinite(t.offset)) return false;
            auto rect=rectangle(t.bounds);
            if (int64_t(rect[2]-rect[0]+1)*(rect[3]-rect[1]+1)>1000000) return false;
            for (int y=rect[1];y<=rect[3];++y) for (int x=rect[0];x<=rect[2];++x) bins[{x,y}].push_back(int(i));
            triangles.push_back(t);
        }
        return true;
    }
    static std::array<int,4> rectangle(Rect2 r) {
        Vector2 end=r.position+r.size;
        return {int(std::floor(r.position.x/4.0)),int(std::floor(r.position.y/4.0)),
                int(std::floor(end.x/4.0)),int(std::floor(end.y/4.0))};
    }
    std::vector<Polygon> fragments(int index) {
        const Triangle &source=triangles[index];
        auto key=rectangle(source.bounds);
        auto found=candidates.find(key);
        if (found==candidates.end()) {
            std::set<int> seen;
            std::vector<int> list;
            for (int y=key[1];y<=key[3];++y) for (int x=key[0];x<=key[2];++x) {
                for (int other:bins[{x,y}]) if (seen.insert(other).second) list.push_back(other);
            }
            found=candidates.emplace(key,std::move(list)).first;
        }
        std::vector<Polygon> remaining{source.polygon};
        for (int other:found->second) {
            if (stop->check()) return {};
            if (other==index) continue;
            const Triangle &rival=triangles[other];
            if (!source.bounds.intersects(rival.bounds)) continue;
            Vector2 gradient=rival.gradient-source.gradient;
            double offset=rival.offset-source.offset;
            Polygon cutter;
            if (gradient.length_squared()<0.00000001) {
                if (offset>0.000001 || (std::abs(offset)<=0.000001 && other>index)) continue;
                cutter=rival.polygon;
            } else cutter=lower_half(rival.polygon,gradient,offset);
            if (cutter.size()<3) continue;
            std::vector<Polygon> next;
            for (const Polygon &fragment:remaining) {
                if (stop->check()) return {};
                auto parts=subtract(fragment,cutter,geometry);
                next.insert(next.end(),parts.begin(),parts.end());
            }
            remaining=std::move(next);
            if (remaining.empty()) break;
        }
        return remaining;
    }
};

// Scalar calculations retain GDScript's double intermediates; Vector2 operations
// retain the engine's float rounding boundaries and strict first-nearest ties.
inline Vector2 sand_uv(Vector2 point,const Polygon &points) {
    double best=std::numeric_limits<double>::infinity(),along=0;
    Vector2 result;
    for (int64_t i=0;i<points.size()-1;++i) {
        Vector2 delta=points[i+1]-points[i];
        double length=delta.length();
        if (length<0.00001) continue;
        Vector2 direction=delta/float(length);
        double projected=clamp((point-points[i]).dot(direction),0,length);
        Vector2 nearest=points[i]+direction*float(projected);
        double distance=point.distance_squared_to(nearest);
        if (distance<best) { best=distance; result=Vector2(float(along+projected),(point-nearest).dot(direction.orthogonal())); }
        along+=length;
    }
    return result;
}
inline Vector2 asphalt_uv(Vector2 point,const Polygon &points,Object *geometry) {
    double best=std::numeric_limits<double>::infinity();
    Vector2 result;
    for (int64_t i=0;i<points.size()-1;++i) {
        Vector2 a=points[i],b=points[i+1];
        Vector2 nearest=closest(geometry,point,a,b);
        double distance=point.distance_squared_to(nearest);
        if (distance<best && a.distance_squared_to(b)>0.000001) {
            best=distance;
            Vector2 direction=(b-a).normalized();
            result=Vector2(float(double(direction.x)*direction.x-double(direction.y)*direction.y),float(-2.0*direction.x*direction.y));
        }
    }
    return result;
}
inline Vector2 coordinates(Vector2 local,const Dictionary &settings) {
    double sign=settings.get("desert_sign",1.0),phase=settings.get("desert_phase",0.0),scale=settings.get("desert_scale",1.0);
    return Vector2(float((double(local.x)*sign+phase)*scale),float(double(local.y)*sign));
}
struct BlendPiece {
    Polygon points;
    std::vector<std::pair<Polygon,bool>> outlines;
    Rect2 bounds;
    std::map<std::pair<int,int>,std::vector<std::array<Vector2,2>>> edges;
    std::vector<int> candidates;
    Dictionary settings;
};
struct Blend {
    std::map<int,BlendPiece> pieces;
    Object *geometry;
    bool load(const Dictionary &data) {
        Dictionary points=data.get("points",Dictionary()),outlines=data.get("outlines",Dictionary()),
            bounds=data.get("bounds",Dictionary()),candidates=data.get("candidates",Dictionary()),settings=data.get("settings",Dictionary());
        Array keys=points.keys();
        for (int64_t i=0;i<keys.size();++i) {
            int index=int64_t(keys[i]); BlendPiece &piece=pieces[index];
            piece.points=points[index]; piece.bounds=bounds.get(index,Rect2());
            // The pinned godot-cpp Dictionary move assignment constructs over
            // its destination without releasing it. Use its releasing copy
            // assignment so each blend piece drops the initial empty dictionary.
            const Dictionary piece_settings=settings.get(index,Dictionary());
            piece.settings=piece_settings;
            Array choices=candidates.get(index,Array());
            for (int64_t j=0;j<choices.size();++j) piece.candidates.push_back(int64_t(choices[j]));
            Array loops=outlines.get(index,Array());
            for (int64_t j=0;j<loops.size();++j) {
                Dictionary loop=loops[j]; Polygon polygon=loop["polygon"];
                piece.outlines.push_back({polygon,bool(loop.get("hole",false))});
                for (int64_t k=0;k<polygon.size();++k) {
                    Vector2 a=polygon[k],b=polygon[(k+1)%polygon.size()];
                    Rect2 rect(a,Vector2());rect.expand_to(b);rect=rect.grow(2.5);
                    Vector2 end=rect.position+rect.size;
                    for (int y=int(std::floor(rect.position.y/6.0));y<=int(std::floor(end.y/6.0));++y)
                        for (int x=int(std::floor(rect.position.x/6.0));x<=int(std::floor(end.x/6.0));++x) piece.edges[{x,y}].push_back({a,b});
                }
            }
        }
        return true;
    }
    double strength(Vector2 point,int index) {
        auto found=pieces.find(index);
        if (found==pieces.end() || !found->second.bounds.grow(2.5).has_point(point)) return 0;
        BlendPiece &piece=found->second;
        bool inside=false,hole=false;
        for (const auto &outline:piece.outlines) if (bool(contains(geometry,point,outline.first))) {
            if (outline.second) hole=true;else inside=true;
        }
        double nearest=std::numeric_limits<double>::infinity();
        auto edges=piece.edges.find({int(std::floor(point.x/6.0)),int(std::floor(point.y/6.0))});
        if (edges!=piece.edges.end()) for (const auto &edge:edges->second) {
            Vector2 closest_point=closest(geometry,point,edge[0],edge[1]);
            nearest=std::min(nearest,double(point.distance_to(closest_point)));
        }
        double t=clamp(((inside&&!hole?nearest:-nearest)+2.5)/5.0,0,1);
        return t*t*(3.0-2.0*t);
    }
    Color color(Vector2 point,int index) {
        Color encoded(1,0.5,0.5,0);
        auto found=pieces.find(index); if (found==pieces.end()) return encoded;
        int other_index=-1;double other_strength=0;
        for (int other:found->second.candidates) {
            double value=strength(point,other);
            if (value>other_strength) {other_strength=value;other_index=other;}
        }
        if (other_strength>0.001) {
            BlendPiece &other=pieces[other_index];
            Vector2 uv=coordinates(sand_uv(point,other.points),other.settings);
            double weight=other_strength/std::max(strength(point,index)+other_strength,0.001);
            constexpr double tau=6.28318530717958647692;
            encoded=Color(float(0.5+std::cos(tau*uv.x/10.0)*0.5),float(0.5+std::sin(tau*uv.x/10.0)*0.5),float(clamp(double(uv.y)/32.0+0.5,0,1)),float(weight));
        }
        return encoded;
    }
};

struct Emitter {
    Object *geometry,*tool;
    Stop *stop;
    Blend blending;
    int mode=0; // 0 road polygon/union, 1 fringe
    String theme;
    double height=0;
    std::map<Vector2,Vector2> sand_cache,axis_cache;
    void vertex(Vector2 point,const Polygon &points,const Dictionary &settings) {
        if (stop->check()) return;
        if ((theme=="desert" || theme=="winter") && !points.is_empty()) {
            auto found=sand_cache.find(point);
            if (found==sand_cache.end()) found=sand_cache.emplace(point,sand_uv(point,points)).first;
            set_uv(tool,theme=="desert"?coordinates(found->second,settings):found->second);
            if (theme=="desert" && settings.has("desert_piece_index")) set_color(tool,blending.color(point,int64_t(settings["desert_piece_index"])));
            if (theme=="winter") {
                double half=5.0;
                if (settings.has("winter_widths")) {
                    PackedFloat32Array widths=settings["winter_widths"],distances=settings["winter_distances"];
                    if (widths.size()>1 && widths.size()==distances.size()) {
                        int lo=0,hi=distances.size()-1;
                        while (hi-lo>1) {int mid=(lo+hi)/2;if (distances[mid]<=found->second.x)lo=mid;else hi=mid;}
                        // PackedFloat32 scalar subtraction is a GDScript double operation.
                        double fraction=clamp((double(found->second.x)-distances[lo])/std::max(double(distances[hi])-distances[lo],0.0001),0,1);
                        half=(double(widths[lo])+(double(widths[hi])-widths[lo])*fraction)*0.5;
                    }
                }
                set_color(tool,Color(float(half/32.0+0.5/255.0),0,0,1));
            }
        }
        auto axis=axis_cache.find(point);
        if (axis==axis_cache.end()) axis=axis_cache.emplace(point,asphalt_uv(point,points,geometry)).first;
        set_uv2(tool,axis->second);
        add_vertex(tool,world(point)+Vector3(0,float(height),0));
    }
    void triangle(Vector2 a,Vector2 b,Vector2 c,const Polygon &points,const Dictionary &settings,int depth=0) {
        if (stop->check()) return;
        double ab=a.distance_squared_to(b),bc=b.distance_squared_to(c),ca=c.distance_squared_to(a);
        if ((theme=="desert" || theme=="winter") && !points.is_empty() && std::max(ab,std::max(bc,ca))>4.0 && depth<12) {
            if (bc>=ab && bc>=ca) triangle(b,c,a,points,settings,depth+1);
            else if (ca>ab) triangle(c,a,b,points,settings,depth+1);
            else {Vector2 middle=(a+b)*0.5f;triangle(a,middle,c,points,settings,depth+1);triangle(middle,b,c,points,settings,depth+1);}
            return;
        }
        vertex(a,points,settings);vertex(b,points,settings);vertex(c,points,settings);
    }
    int polygon(const Polygon &polygon,const Polygon &points,const Dictionary &settings) {
        PackedInt32Array indices=triangulate(geometry,polygon);
        sand_cache.clear();
        for (int64_t i=0;i<indices.size();i+=3) {
            if (stop->check()) return 0;
            triangle(polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]],points,settings);
        }
        return indices.size()/3;
    }
};

inline Dictionary collect(const Array &input,bool grass,Object *geometry,const Callable &cancelled) {
    Stop stop{cancelled};Clip clip;clip.geometry=geometry;clip.stop=&stop;
    if (!geometry || !clip.load(input)) return {};
    PackedVector2Array points,uv;
    for (int i=0;i<int(clip.triangles.size());++i) {
        const Triangle &source=clip.triangles[i];
        for (const auto &polygon:clip.fragments(i)) {
            PackedInt32Array indices=triangulate(geometry,polygon);
            for (int64_t j=0;j<indices.size();++j) {
                if (stop.check()) return {};
                Vector2 p=polygon[indices[j]];
                double across=clamp(double(source.gradient.dot(p))+source.offset,0,1),height=0;
                if (grass) height=source.has_height?clamp(double(source.height_gradient.dot(p))+source.height_offset,-0.038,0.027):0.027+(-0.038-0.027)*across;
                points.append(p);uv.append(Vector2(float(height),float(across)));
            }
        }
        if (stop.aborted) return {};
    }
    Dictionary data;data["points"]=points;data["uv"]=uv;return data;
}

struct Cut { Vector2 point,normal; double span; };
inline bool on_cut(Vector2 a,Vector2 b,const std::vector<Cut> &cuts,bool cap=false) {
    for (const auto &cut:cuts) {
        if (std::abs((a-cut.point).dot(cut.normal))>=0.001 || std::abs((b-cut.point).dot(cut.normal))>=0.001) continue;
        if (cap) {
            if (std::abs(((a+b)*0.5f-cut.point).dot(cut.normal.orthogonal()))<=cut.span*0.5+1.2) return true;
        } else if (a.distance_to(b)>cut.span*0.5) return true;
    }
    return false;
}
inline Vector2 miter(const Polygon &polygon,int index,const std::vector<Cut> &cuts,bool swept) {
    int size=polygon.size();Vector2 point=polygon[index],before=polygon[(index+size-1)%size],after=polygon[(index+1)%size];
    double area=0;
    for (int i=0;i<size;++i) area+=polygon[i].cross(polygon[(i+1)%size]);
    if (swept) {
        Vector2 tangent;
        if (on_cut(before,point,cuts,true)) tangent=after-point;
        else if (on_cut(point,after,cuts,true)) tangent=point-before;
        if (tangent!=Vector2()) {
            Vector2 normal=tangent.normalized().orthogonal();
            return area<0?-normal:normal;
        }
    } else if (on_cut(before,point,cuts) || on_cut(point,after,cuts)) {
        // Preserve NativeTrackVisual's original non-swept join-plane miter.
        for (const auto &cut:cuts) if (std::abs((point-cut.point).dot(cut.normal))<0.001) {
            Vector2 normal=cut.normal.orthogonal();
            if (normal.dot(point-cut.point)<0) normal=-normal;
            return normal;
        }
    }
    Vector2 a=(point-before).normalized().orthogonal(),b=(after-point).normalized().orthogonal();
    Vector2 normal=(a+b).normalized();
    if (area<0) normal=-normal;
    return normal/float(std::max(std::abs(double(normal.dot(b))),0.5));
}
inline Dictionary edge_samples(const Array &contours,const Array &input_cuts,const Array &outlines,
                                const Array &joined,int index,bool swept,bool winter,Object *geometry,const Callable &cancelled) {
    if (!geometry) return {};
    Stop stop{cancelled};std::vector<Cut> cuts;
    for (int64_t i=0;i<input_cuts.size();++i) {
        Dictionary cut=input_cuts[i];cuts.push_back({cut["point"],cut["normal"],double(cut["span"])});
    }
    // Decode immutable outline fields once, rather than crossing the Variant
    // dictionary boundary for every 20 cm roadside probe on every section.
    struct EdgeOutline { Polygon polygon; Rect2 bounds; int index; bool hole; };
    std::vector<EdgeOutline> edge_outlines;
    edge_outlines.reserve(outlines.size());
    for (int64_t i=0;i<outlines.size();++i) {
        Dictionary outline=outlines[i];
        edge_outlines.push_back({outline["polygon"],outline["bounds"],int(int64_t(outline["index"])),bool(outline.get("hole",false))});
    }
    PackedVector2Array result;
    for (int64_t loop=0;loop<contours.size();++loop) {
        Polygon polygon=contours[loop];if (polygon.size()<3) continue;
        bool hole=swept && bool(clockwise(geometry,polygon));
        for (int edge=0;edge<polygon.size();++edge) {
            if (stop.check()) return {};
            Vector2 a=polygon[edge],b=polygon[(edge+1)%polygon.size()];
            if (on_cut(a,b,cuts) || (swept && on_cut(a,b,cuts,true))) continue;
            Vector2 na=miter(polygon,edge,cuts,swept),nb=miter(polygon,(edge+1)%polygon.size(),cuts,swept);
            if (hole) {na=-na;nb=-nb;}
            int steps=std::max(1,int(std::ceil(a.distance_to(b)/(winter?0.28:0.20))));
            for (int step=0;step<steps;++step) {
                if (stop.check()) return {};
                Vector2 p=a.lerp(b,float(double(step)/steps)),q=a.lerp(b,float(double(step+1)/steps));
                Vector2 np=na.lerp(nb,float(double(step)/steps)),nq=na.lerp(nb,float(double(step+1)/steps));
                Vector2 across=(q-p).normalized().orthogonal()*0.085f,midpoint=(p+q)*0.5f,outward=across*5.0f;
                if (bool(contains(geometry,midpoint+outward,polygon))!=hole) outward=-outward;
                Vector2 probe=midpoint+outward;
                std::map<int,int> coverage;
                for (const EdgeOutline &outline:edge_outlines) {
                    int other=outline.index;
                    if (other==index || !outline.bounds.has_point(probe)) continue;
                    bool neighbor=false;
                    for (int64_t j=0;j<joined.size();++j) {
                        Dictionary join=joined[j];
                        if (int64_t(join["index"])==other && probe.distance_to(Vector2(join["position"]))<double(join["width"])) {neighbor=true;break;}
                    }
                    if (!neighbor && bool(contains(geometry,probe,outline.polygon))) coverage[other]+=outline.hole?-1:1;
                }
                bool exposed=true;
                for (auto value:coverage) if (value.second>0) {exposed=false;break;}
                if (!exposed) continue;
                result.append(p);result.append(q);result.append(np);result.append(nq);
            }
        }
    }
    return road_geometry::result("samples",result);
}

inline Dictionary emit(const Array &input,const Array &paths,const Array &settings,const Dictionary &blend,
                       String theme,int mode,double height,Object *geometry,Object *tool,const Callable &cancelled) {
    Stop stop{cancelled};Clip clip;clip.geometry=geometry;clip.stop=&stop;
    if (!geometry || !tool || paths.size()!=input.size() || settings.size()!=input.size() || !clip.load(input)) return {};
    Emitter output;output.geometry=geometry;output.tool=tool;output.stop=&stop;output.theme=theme;output.height=height;
    output.blending.geometry=geometry;output.blending.load(blend);
    int count=0;
    for (int i=0;i<int(clip.triangles.size());++i) {
        Polygon path=paths[i];Dictionary phase=settings[i];
        output.axis_cache.clear();
        for (const Polygon &polygon:clip.fragments(i)) {
            if (stop.check()) return {};
            if (mode==0) count+=output.polygon(polygon,path,phase);
            else {
                PackedInt32Array indices=triangulate(geometry,polygon);
                for (int64_t j=0;j<indices.size();++j) {
                    if (stop.check()) return {};
                    Vector2 p=polygon[indices[j]];
                    set_uv(tool,Vector2(0,float(clamp(double(clip.triangles[i].gradient.dot(p))+clip.triangles[i].offset,0,1))));
                    if (theme=="desert") {
                        set_uv2(tool,coordinates(sand_uv(p,path),phase));
                        set_color(tool,output.blending.color(p,int64_t(phase.get("desert_piece_index",-1))));
                    } else set_uv2(tool,asphalt_uv(p,path,geometry));
                    add_vertex(tool,world(p)+Vector3(0,0.013f,0));
                }
                count+=indices.size()/3;
            }
        }
        if (stop.aborted) return {};
    }
    return road_geometry::result("count",count);
}

// No rendering resources: final vertex streams are assembled on the CPU.
inline Array unpack(const Array &input,bool decode) {
    if (input.size()<=INDEX) return {};
    Array output=input.duplicate();
    if (decode && input[NORMAL].get_type()==Variant::PACKED_VECTOR3_ARRAY) {
        PackedVector3Array normals=input[NORMAL];normals=normals.duplicate();
        Vector3 *values=normals.ptrw();
        for (int64_t i=0;i<normals.size();++i) {
            Vector2 packed=values[i].octahedron_encode()*65535.0f;
            Vector2 oct(float(clamp(int64_t(packed.x),0,65535)/65535.0),float(clamp(int64_t(packed.y),0,65535)/65535.0));
            values[i]=Vector3::octahedron_decode(oct);
        }
        output[NORMAL]=normals;
    }
    if (input[COLOR].get_type()==Variant::PACKED_COLOR_ARRAY) {
        PackedColorArray colors=input[COLOR];colors=colors.duplicate();Color *values=colors.ptrw();
        for (int64_t i=0;i<colors.size();++i) {
            Color c=values[i];
            values[i]=Color(float(clamp(int64_t(double(c.r)*255.0),0,255)/255.0),float(clamp(int64_t(double(c.g)*255.0),0,255)/255.0),
                            float(clamp(int64_t(double(c.b)*255.0),0,255)/255.0),float(clamp(int64_t(double(c.a)*255.0),0,255)/255.0));
        }
        output[COLOR]=colors;
    }
    return output;
}
inline Array finish(const Array &input,const Dictionary &flags,const Callable &cancelled) {
    if (input.size()<=INDEX || input[VERTEX].get_type()!=Variant::PACKED_VECTOR3_ARRAY) return {};
    PackedVector3Array positions=input[VERTEX],normals;
    PackedVector2Array uv,uv2;PackedColorArray colors;
    if (positions.size()%3) return {};
    if (input[NORMAL].get_type()==Variant::PACKED_VECTOR3_ARRAY) normals=input[NORMAL];
    if (input[UV].get_type()==Variant::PACKED_VECTOR2_ARRAY) uv=input[UV];
    if (input[UV2].get_type()==Variant::PACKED_VECTOR2_ARRAY) uv2=input[UV2];
    if (input[COLOR].get_type()==Variant::PACKED_COLOR_ARRAY) colors=input[COLOR];
    int64_t n=positions.size();
    if ((!normals.is_empty()&&normals.size()!=n)||(!uv.is_empty()&&uv.size()!=n)||(!uv2.is_empty()&&uv2.size()!=n)||(!colors.is_empty()&&colors.size()!=n)) return {};
    PackedVector3Array output_positions,output_normals;
    PackedVector2Array output_uv,output_uv2;PackedColorArray output_colors;
    output_positions.resize(n);output_normals.resize(n);
    if (!uv.is_empty()) output_uv.resize(n);
    if (!uv2.is_empty()) output_uv2.resize(n);
    if (!colors.is_empty()) output_colors.resize(n);
    auto p=output_positions.ptrw();auto ns=output_normals.ptrw();
    auto u=output_uv.ptrw();auto u2=output_uv2.ptrw();auto cs=output_colors.ptrw();
    bool solid=flags.get("solid",false),grass=flags.get("grass",false),desert_gravel=flags.get("desert_gravel",false),
        asphalt=flags.get("asphalt",false),fringe=flags.get("fringe",false);
    Stop stop{cancelled};
    for (int64_t first=0;first<n;first+=3) {
        if (stop.check()) return {};
        int order[3]={0,1,2};
        Vector3 face=(positions[first+2]-positions[first]).cross(positions[first+1]-positions[first]).normalized();
        if ((positions[first+1]-positions[first]).cross(positions[first+2]-positions[first]).y>0) {order[1]=2;order[2]=1;}
        for (int j=0;j<3;++j) {
            int64_t source=first+order[j],target=first+j;
            Vector3 normal(0,1,0);
            if (grass && !normals.is_empty()) normal=normals[source];
            else if (solid && std::abs(face.y)<0.99999) normal=normals.is_empty()?face:normals[source];
            else if (asphalt && !fringe && std::abs(face.y)<0.5) normal=face;
            else if (desert_gravel && !normals.is_empty() && !uv.is_empty() && uv[source].x < -0.5) normal=normals[source];
            p[target]=positions[source];ns[target]=normal;
            if (u)u[target]=uv[source];if (u2)u2[target]=uv2[source];if (cs)cs[target]=colors[source];
        }
    }
    Array output;output.resize(13);
    output[VERTEX]=output_positions;output[NORMAL]=output_normals;
    if (!uv.is_empty())output[UV]=output_uv;
    if (!uv2.is_empty())output[UV2]=output_uv2;
    if (!colors.is_empty())output[COLOR]=output_colors;
    // Preserve SurfaceTool's exact index welding for Desert decorative banks.
    if (desert_gravel) {
        Variant reference=ClassDBSingleton::get_singleton()->instantiate("SurfaceTool");Object *tool=reference;
        tool->call("create_from_arrays",output);tool->call("index");output=tool->call("commit_to_arrays");
    }
    return output;
}
} // namespace road_geometry
