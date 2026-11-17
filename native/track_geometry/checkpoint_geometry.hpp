// Exact preparation-only ports. Vector operations remain real_t; script scalar
// intermediates remain double. No simulation, persistence or shared job state.
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <map>
#include <vector>
namespace checkpoint_geometry {
using Cell = std::pair<int,int>;
using Bins = std::map<Cell,std::vector<int>>;
inline bool cell(Vector2 point,Cell &result) {
    Vector2 scaled=(point/8.0f).floor();
    if (!scaled.is_finite() || std::abs(double(scaled.x))>100000000 || std::abs(double(scaled.y))>100000000) return false;
    result={int(scaled.x),int(scaled.y)};return true;
}
inline bool bounds(Vector2 a,Vector2 b,Cell &low,Cell &high) {
    return cell(a,low) && cell(b,high) &&
        int64_t(high.first-low.first+1)*(high.second-low.second+1)<=1048576;
}
inline Variant intersection(Object *geometry,const Vector2 &a,const Vector2 &b,const Vector2 &c,const Vector2 &d) {
    static auto method=road_geometry::binding("Geometry2D","segment_intersects_segment",2058025344);
    return internal::_call_native_mb_ret<Variant>(method,geometry->_owner,&a,&b,&c,&d);
}
inline PackedFloat64Array crossings(const PackedVector2Array &centers,const PackedVector2Array &directions,const PackedVector2Array &widths,const PackedVector2Array &path) {
    if (directions.size()!=centers.size() || widths.size()!=centers.size() || path.size()<2 || path.size()>262144) return {};
    Bins bins;int64_t inserted=0;
    for (int i=0;i<path.size()-1;++i) {
        Cell low,high;
        if (!bounds(path[i].min(path[i+1]),path[i].max(path[i+1]),low,high)) return {};
        for (int y=low.second;y<=high.second;++y) for (int x=low.first;x<=high.first;++x) {
            if (++inserted>2097152) return {};
            bins[{x,y}].push_back(i);
        }
    }
    PackedFloat64Array result;result.resize(centers.size());auto *events=result.ptrw();
    std::vector<int> candidates;
    for (int gate=0;gate<centers.size();++gate) {
        Vector2 center=centers[gate],direction=directions[gate],normal=direction.orthogonal(),width=widths[gate];
        if (!center.is_finite() || !direction.is_finite() || !width.is_finite()) return {};
        Vector2 left=center-normal*width.x,right=center+normal*width.y;
        Cell low,high;
        if (!bounds(left.min(right)-Vector2(1,1)*real_t(0.001),left.max(right)+Vector2(1,1)*real_t(0.001),low,high)) return {};
        candidates.clear();
        for (int y=low.second;y<=high.second;++y) for (int x=low.first;x<=high.first;++x) {
            auto found=bins.find({x,y});
            if (found!=bins.end()) candidates.insert(candidates.end(),found->second.begin(),found->second.end());
        }
        std::sort(candidates.begin(),candidates.end());
        candidates.erase(std::unique(candidates.begin(),candidates.end()),candidates.end());
        double event=-1.0,nearest=std::numeric_limits<double>::infinity();
        for (int i:candidates) {
            double before=(path[i]-center).dot(direction),after=(path[i+1]-center).dot(direction);
            double f=before<=0.0 && after>0.0 ? -before/(after-before) : -1.0;
            if (f<0.0) continue;
            Vector2 point=path[i].lerp(path[i+1],real_t(f));
            double lateral=(point-center).dot(normal);
            if (lateral < -double(width.x) || lateral>double(width.y)) continue;
            double distance=point.distance_squared_to(center);
            if (distance<nearest) {nearest=distance;event=i+f;}
        }
        events[gate]=event;
    }
    return result;
}
struct Route {
    PackedVector2Array points;
    PackedFloat64Array cumulative;
    Bins bins;
    bool prepare(const PackedVector2Array &route,const PackedFloat64Array &distances) {
        points={};cumulative={};bins.clear();
        if (route.is_empty() || route.size()!=distances.size() || route.size()>262144) return false;
        for (int i=0;i<route.size();++i) {
            Cell key;if (!cell(route[i],key)) {bins.clear();return false;}
            bins[key].push_back(i);
        }
        points=route;cumulative=distances;return true;
    }
    double projection(Vector2 point) const {
        Cell key;if (points.is_empty() || !cell(point,key)) return std::numeric_limits<double>::quiet_NaN();
        double best=std::numeric_limits<double>::infinity();int nearest=0;
        for (int y=-2;y<=2;++y) for (int x=-2;x<=2;++x) {
            auto found=bins.find({key.first+x,key.second+y});
            if (found==bins.end()) continue;
            for (int index:found->second) {
                double distance=point.distance_squared_to(points[index]);
                if (distance<best || (distance==best && index<nearest)) {best=distance;nearest=index;}
            }
        }
        if (best>256.0) {
            best=std::numeric_limits<double>::infinity();nearest=0;
            for (int index=0;index<points.size();++index) {
                double distance=points[index].distance_squared_to(point);
                if (distance<best) {best=distance;nearest=index;}
            }
        }
        best=std::numeric_limits<double>::infinity();double progress=cumulative[nearest];
        for (int offset=-1;offset<=1;++offset) {
            int index=(nearest+offset+points.size())%points.size();
            Vector2 edge=points[(index+1)%points.size()]-points[index];
            double fraction=std::clamp(double((point-points[index]).dot(edge))/std::max(double(edge.length_squared()),0.000001),0.0,1.0);
            double distance=point.distance_squared_to(points[index]+edge*real_t(fraction));
            if (distance<best) {best=distance;progress=cumulative[index]+double(edge.length())*fraction;}
        }
        return progress;
    }
};
inline PackedVector2Array lane(const PackedVector2Array &route,const Dictionary &basis,double fraction,bool constant_width,bool rejoin_start,double recovery,Object *geometry) {
    PackedVector2Array normals=basis.get("normals",PackedVector2Array());
    PackedFloat64Array halves=basis.get("halves",PackedFloat64Array()),rejoins=basis.get("rejoins",PackedFloat64Array());
    double minimum=basis.get("minimum_half",0.0);
    if (!geometry || route.size()<2 || route.size()>262144 || normals.size()!=route.size() || halves.size()!=route.size() || rejoins.size()!=route.size()) return {};
    std::vector<Vector2> path;path.reserve(route.size()+2);
    for (int i=0;i<route.size();++i) {
        double half=constant_width?std::min(halves[i],minimum):halves[i];
        double lateral=(half+recovery)*fraction;
        path.push_back(route[i]+normals[i]*real_t(lateral)*real_t(rejoin_start?rejoins[i]:1.0));
    }
    path.push_back(path[0]);path.push_back(path[1]);
    std::vector<Vector2> result;result.reserve(path.size());
    for (Vector2 point:path) {
        if (result.size()>=3) {
            double travelled=0.0;
            for (int index=int(result.size())-3;index>=0;--index) {
                travelled+=result[index].distance_to(result[index+1]);
                if (travelled>20.0) break;
                Variant hit=intersection(geometry,result[index],result[index+1],result.back(),point);
                if (hit.get_type()==Variant::VECTOR2 && Vector2(hit).distance_to(point)>0.001) {
                    result.resize(index+1);result.push_back(hit);break;
                }
            }
        }
        result.push_back(point);
    }
    PackedVector2Array output;output.resize(result.size());auto *values=output.ptrw();
    std::copy(result.begin(),result.end(),values);return output;
}
}
