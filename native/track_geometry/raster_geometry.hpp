// NWR04: original, scalar-equivalent compiler raster and editor mask kernels.
namespace raster_geometry {
using namespace road_geometry;
struct Grid {
    Vector2i size;
    Vector2 extent;
    double step;
    PackedInt32Array cells,mask;
    PackedByteArray exclusion;
    bool load(const Dictionary &data) {
        size=data.get("grid",Vector2i()); extent=data.get("extent",Vector2()); step=data.get("cell_size",0.0);
        cells=data.get("cells",PackedInt32Array()); mask=data.get("mask",PackedInt32Array());
        exclusion=data.get("exclusion",PackedByteArray());
        return size.x>0 && size.y>0 && int64_t(size.x)*size.y==cells.size() && cells.size()<=16000000 &&
            (mask.is_empty() || mask.size()==cells.size()) && (exclusion.is_empty() || exclusion.size()==cells.size()) && std::isfinite(step) && step>0 && extent.is_finite();
    }
    Vector2 point(int x,int y) const {return Vector2(float((x+0.5)*step-extent.x),float(extent.y-(y+0.5)*step));}
    Dictionary output() const {Dictionary d;d["cells"]=cells;d["mask"]=mask;if (!exclusion.is_empty()) d["exclusion"]=exclusion;return d;}
};
inline Dictionary road(const Dictionary &data,Object *geometry,const Callable &cancelled) {
    Grid g;if (!geometry || !g.load(data)) return {};
    Polygon route=data.get("route",Polygon());PackedFloat32Array widths=data.get("widths",PackedFloat32Array());
    if (route.size()!=widths.size() || route.size()<2) return {};
    for (int64_t i=0;i<route.size();++i) if (!route[i].is_finite() || !std::isfinite(widths[i]) || widths[i]<0) return {};
    int kind=data.get("kind",0);bool closed=data.get("closed",false),has_mask=!g.mask.is_empty();
    int32_t *values=g.cells.ptrw(),*mask=has_mask?g.mask.ptrw():nullptr;
    Stop stop{cancelled};
    for (int64_t i=0;i<(closed?route.size():route.size()-1);++i) {
        if (stop.check()) return {};
        Vector2 a=route[i],b=route[(i+1)%route.size()];
        double ra=double(widths[i])*0.5,rb=double(widths[(i+1)%widths.size()])*0.5,margin=std::max(ra,rb)+1.0;
        int x0=std::max(0,int(std::floor((std::min(a.x,b.x)-margin+g.extent.x)/g.step)));
        int x1=std::min(g.size.x-1,int(std::ceil((std::max(a.x,b.x)+margin+g.extent.x)/g.step)));
        int y0=std::max(0,int(std::floor((g.extent.y-std::max(a.y,b.y)-margin)/g.step)));
        int y1=std::min(g.size.y-1,int(std::ceil((g.extent.y-std::min(a.y,b.y)+margin)/g.step)));
        for (int y=y0;y<=y1;++y) {
            if (stop.check()) return {};
            for (int x=x0;x<=x1;++x) {
                int at=y*g.size.x+x;
                if (values[at]==kind && (!has_mask || mask[at]==kind)) continue;
                Vector2 p=g.point(x,y),near=closest(geometry,p,a,b);
                double distance=p.distance_squared_to(near);
                double weight=clamp(double((near-a).dot(b-a))/std::max(0.0001,double(a.distance_squared_to(b))),0,1);
                double radius=ra+(rb-ra)*weight;
                if (distance<=radius*radius) {values[at]=kind;if (has_mask) mask[at]=kind;}
                else if (distance<=(radius+1.0)*(radius+1.0)) {
                    int value=values[at];if (value>=1 && value<=3 && value!=kind) values[at]=5;
                    if (has_mask) {value=mask[at];if (value>=1 && value<=3 && value!=kind) mask[at]=5;}
                }
            }
        }
    }
    return g.output();
}
inline Dictionary paint(const Array &strokes,const Dictionary &data,Object *geometry,const Callable &cancelled) {
    Grid g;if (!geometry || !g.load(data) || g.mask.is_empty()) return {};
    int32_t *values=g.cells.ptrw(),*mask=g.mask.ptrw();
    uint8_t *excluded=g.exclusion.is_empty()?nullptr:g.exclusion.ptrw();
    Stop stop{cancelled};
    Dictionary previous;
    for (int64_t s=0;s<strokes.size();++s) {
        if (stop.check() || strokes[s].get_type()!=Variant::DICTIONARY) return {};
        Dictionary stroke=strokes[s];Polygon points=stroke.get("points",Polygon());
        if (s>0 && stroke.recursive_equal(previous,0)) continue;
        previous=stroke;
        if (points.is_empty()) continue;
        for (int64_t i=0;i<points.size();++i) if (!points[i].is_finite()) return {};
        bool area=String(stroke.get("mode",""))=="area",round=String(stroke.get("shape","round"))=="round",protect=stroke.get("protect_road",false);
        double radius=double(stroke.get("width",0.0))*0.5;int surface=stroke.get("surface",0);
        if (!std::isfinite(radius) || radius<0) return {};
        Vector2 low=points[0],high=low;
        // Repeated capsules within one stroke only assign the same constants;
        // retain endpoint orientation for exact floating-point coverage.
        std::set<std::array<float,4>> visited;
        if (area) for (int64_t i=0;i<points.size();++i) {low=low.min(points[i]);high=high.max(points[i]);}
        for (int64_t i=0;i<(area?1:points.size());++i) {
            Vector2 a=points[i],b=points[std::max(int64_t(0),i-1)];
            if (!area && !visited.insert({a.x,a.y,b.x,b.y}).second) continue;
            if (!area) {low=a.min(b)-Vector2(1,1)*float(radius);high=a.max(b)+Vector2(1,1)*float(radius);}
            int x0=std::max(0,int(std::floor((double(low.x)+g.extent.x)/g.step))),x1=std::min(g.size.x,int(std::ceil((double(high.x)+g.extent.x)/g.step)));
            int y0=std::max(0,int(std::floor((double(g.extent.y)-high.y)/g.step))),y1=std::min(g.size.y,int(std::ceil((double(g.extent.y)-low.y)/g.step)));
            for (int y=y0;y<y1;++y) {
                if (stop.check()) return {};
                for (int x=x0;x<x1;++x) {
                    int at=y*g.size.x+x;
                    if (values[at]==surface && mask[at]==(surface==0?0:1) && (!excluded || protect || excluded[at]!=0)) continue;
                    Vector2 p=g.point(x,y);bool hit;
                    if (area) hit=contains(geometry,p,points);
                    else {Vector2 d=p-closest(geometry,p,a,b);hit=round?double(d.length_squared())<=radius*radius:std::max(std::abs(double(d.x)),std::abs(double(d.y)))<=radius;}
                    if (hit && excluded && !protect) excluded[at]=1;
                    if (hit && !(protect && (mask[at]==0 || mask[at]==2))) {values[at]=surface;mask[at]=surface==0?0:1;}
                }
            }
        }
    }
    return g.output();
}
inline PackedByteArray pixels(const PackedInt32Array &cells,const PackedByteArray &excluded,bool overlay) {
    PackedByteArray out;if (cells.size()>16000000 || (overlay && excluded.size()!=cells.size())) return out;
    out.resize(cells.size()*(overlay?3:1));uint8_t *p=out.ptrw();
    for (int64_t i=0;i<cells.size();++i) {
        if (overlay) {p[i*3]=excluded[i]==0?255:0;p[i*3+1]=(cells[i]==-1 || cells[i]==1)?255:0;p[i*3+2]=cells[i]==2?255:0;}
        else p[i]=cells[i]==0?255:0;
    }
    return out;
}
}
