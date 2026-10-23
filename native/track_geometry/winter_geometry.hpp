// NWR03: original Winter bank profiles, normals, emission and marker selection.
#include <godot_cpp/variant/vector4.hpp>
namespace winter_geometry {
using namespace road_geometry;
inline double lerp(double a,double b,double t) {return a+(b-a)*t;}
inline double smooth(double a,double b,double value) {double t=clamp((value-a)/(b-a),0,1);return t*t*(3.0-2.0*t);}
inline double noise(Object *source,Vector2 point) {
    static auto method=binding("Noise","get_noise_2dv",2276447920);
    return internal::_call_native_mb_ret<double>(method,source->_owner,&point);
}
using Shape=std::array<double,4>;
inline Shape shape(Object *drift,Vector2 anchor) {
    double d=noise(drift,anchor*float(0.43)),c=noise(drift,anchor*float(0.95)+Vector2(71,13));
    return {-0.50+d*0.24+c*0.16,0.78+d*0.25+c*0.12,4.4+d*0.8,noise(drift,anchor*float(0.23))};
}
inline double offset(const Shape &s,double t) {return t<=0.42?lerp(s[0],s[1],t/0.42):lerp(s[1],s[2],(t-0.42)/0.58);}
inline double height(Object *pack,Vector2 anchor,double t,Vector2 outward,const Shape &s) {
    Vector2 p=anchor+outward*float(offset(s,t));
    double packed=clamp((noise(pack,p)+1.0)*1.5,0,1),peak=0.24+s[3]*0.06;
    double profile=smooth(0,peak,t)*(1.0-smooth(peak+0.15,0.95,t));
    double crest=0.74+s[3]*0.18+packed*0.22,base=lerp(0.018,-0.065,smooth(0.65,1,t));
    return base+crest*profile;
}
inline Vector2 uv(Vector2 p,const Polygon &points,Dictionary &cache) {
    if (!cache.has(p)) cache[p]=sand_uv(p,points);
    return cache[p];
}
inline double fade(double along,const Dictionary &cache) {
    bool start=cache.get("bridge_fade_start",false),end=cache.get("bridge_fade_end",false);
    if (!start && !end) return 1.0;
    double length=cache.get("bridge_fade_length",0.0),reach=std::min(4.0,std::max(0.01,length*0.45)),f=1.0;
    if (start) f*=smooth(0,reach,along);
    if (end) f*=smooth(0,reach,length-along);
    return f;
}
inline Dictionary row(Vector2 anchor,Vector2 outward,const Polygon &points,Dictionary cache,Object *drift,Object *pack) {
    if (!drift || !pack || !anchor.is_finite() || !outward.is_finite()) return {};
    Vector4 key(anchor.x,anchor.y,outward.x,outward.y);
    if (cache.has(key)) return cache[key];
    double end=fade(uv(anchor,points,cache).x,cache);
    Vector2 tangent=outward.normalized().orthogonal(),left=anchor-tangent*float(0.16),right=anchor+tangent*float(0.16);
    Shape s=shape(drift,anchor),ls=shape(drift,left),rs=shape(drift,right);
    double lf=end,rf=end;
    if (end<1) {lf=fade(uv(left,points,cache).x,cache);rf=fade(uv(right,points,cache).x,cache);}
    PackedVector3Array vertices,normals;Polygon uvs;PackedFloat32Array fractions;
    for (float t: {0.0f,0.08f,0.16f,0.24f,0.32f,0.40f,0.48f,0.56f,0.64f,0.75f,0.87f,1.0f}) {
        double dt=t;Vector2 p=anchor+outward*float(offset(s,dt));
        double h=height(pack,anchor,dt,outward,s);
        double slope=(height(pack,anchor,dt+0.06,outward,s)-height(pack,anchor,dt-0.06,outward,s))/(offset(s,dt+0.06)-offset(s,dt-0.06));
        double lh=height(pack,left,dt,outward,ls),rh=height(pack,right,dt,outward,rs);
        if (end<1) {h=lerp(-0.065,h,end);slope*=end;lh=lerp(-0.065,lh,lf);rh=lerp(-0.065,rh,rf);}
        Vector2 gradient=outward.normalized()*float(slope)+tangent*float((rh-lh)/0.32);
        normals.append(Vector3(-gradient.x,1,gradient.y).normalized());uvs.append(uv(p,points,cache));
        vertices.append(world(p)+Vector3(0,1,0)*float(h));fractions.append(t);
    }
    Dictionary result;result["vertices"]=vertices;result["normals"]=normals;result["uvs"]=uvs;result["fractions"]=fractions;
    result["color"]=Color(float(std::abs(double(uv(anchor,points,cache).y))/32.0+0.5/255.0),0,0,1);cache[key]=result;
    return result;
}
inline bool section(Object *tool,const Polygon &anchors,const Polygon &points,Dictionary cache,Object *drift,Object *pack) {
    if (!tool || anchors.size()!=4) return false;
    Dictionary rows[2]={row(anchors[0],anchors[2],points,cache,drift,pack),row(anchors[1],anchors[3],points,cache,drift,pack)};
    if (rows[0].is_empty() || rows[1].is_empty()) return false;
    PackedVector3Array vertices[2]={rows[0]["vertices"],rows[1]["vertices"]},normals[2]={rows[0]["normals"],rows[1]["normals"]};
    Polygon uvs[2]={rows[0]["uvs"],rows[1]["uvs"]};PackedFloat32Array fractions=rows[0]["fractions"];Color colors[2]={rows[0]["color"],rows[1]["color"]};
    for (int band=0;band<11;++band) for (int triangle=0;triangle<2;++triangle) {
        std::array<std::array<int,2>,3> corners=triangle==0?std::array<std::array<int,2>,3>{{{0,band},{1,band+1},{1,band}}}:std::array<std::array<int,2>,3>{{{0,band},{0,band+1},{1,band+1}}};
        Vector3 p=vertices[corners[0][0]][corners[0][1]],q=vertices[corners[1][0]][corners[1][1]],r=vertices[corners[2][0]][corners[2][1]];
        if ((r-p).cross(q-p).y<0) std::swap(corners[1],corners[2]);
        for (auto c:corners) {set_normal(tool,normals[c[0]][c[1]]);set_uv(tool,Vector2(fractions[c[1]],0));set_uv2(tool,uvs[c[0]][c[1]]);set_color(tool,colors[c[0]]);add_vertex(tool,vertices[c[0]][c[1]]);}
    }
    return true;
}
inline Dictionary markers(const Array &triangles,const Polygon &route,const Array &bridges,const Callable &cancelled) {
    if (route.is_empty()) return {};
    struct Bridge {Vector2 origin;float rotation;double length,width;};std::vector<Bridge> spans;
    for (int64_t i=0;i<bridges.size();++i) {Dictionary d=bridges[i];Array p=d.get("position",Array());if (p.size()!=2) return {};spans.push_back({Vector2(float(double(p[0])),float(double(p[1]))),float(-double(d.get("heading",0.0))*0.017453292519943295),double(d.get("length",0.0)),double(d.get("width",0.0))*0.5+0.75});}
    struct Candidate {Vector2 point;int side,index;bool inside;double spacing;};
    std::set<std::array<int,3>> occupied;std::vector<Candidate> candidates,chosen;Stop stop{cancelled};
    for (int64_t t=0;t<triangles.size();++t) {
        if (stop.check() || triangles[t].get_type()!=Variant::DICTIONARY) return {};
        Dictionary d=triangles[t];Polygon points=d.get("points",Polygon());PackedFloat32Array heights=d.get("heights",PackedFloat32Array());
        if (points.size()!=3 || heights.size()!=3) return {};
        for (int i=0;i<3;++i) {
            if (heights[i]<0.30) continue;Vector2 p=points[i];int best=0;double distance=std::numeric_limits<double>::infinity();
            for (int64_t j=0;j<route.size();++j) {if (stop.check()) return {};double ds=route[j].distance_squared_to(p);if (ds<distance) {distance=ds;best=int(j);}}
            int n=int(route.size());Vector2 center=route[best],before=route[(best-3%n+n)%n],after=route[(best+3)%n];
            int side=(after-before).normalized().orthogonal().dot(p-center)>=0?1:-1;
            bool inside=(before+after-center*float(2)).dot(p-center)>0.01;
            std::array<int,3> key={int(std::floor(double(p.x)/6.0)),int(std::floor(double(p.y)/6.0)),side};
            if (occupied.count(key)) continue;bool covered=false;
            for (const Bridge &b:spans) {Vector2 local=(p-b.origin).rotated(b.rotation);if (local.x>=0 && local.x<=b.length && std::abs(double(local.y))<=b.width) {covered=true;break;}}
            if (covered) continue;occupied.insert(key);candidates.push_back({p,side,best,inside,inside?28.0:18.0});
        }
    }
    std::sort(candidates.begin(),candidates.end(),[](const Candidate &a,const Candidate &b) {if (a.inside!=b.inside) return !a.inside;if (a.index!=b.index) return a.index<b.index;if (a.point.x!=b.point.x) return a.point.x<b.point.x;return a.point.y<b.point.y;});
    for (const Candidate &c:candidates) {if (chosen.size()>=40) break;bool clear=true;for (const Candidate &e:chosen) if (c.point.distance_to(e.point)<(c.side==e.side?std::max(c.spacing,e.spacing):7.5)) {clear=false;break;}if (clear) chosen.push_back(c);}
    Array out;for (const Candidate &c:chosen) {Dictionary d;d["position"]=c.point;d["side"]=c.side;d["inside"]=c.inside;d["route"]=c.index;d["spacing"]=c.spacing;out.push_back(d);}
    return result("markers",out);
}
}
