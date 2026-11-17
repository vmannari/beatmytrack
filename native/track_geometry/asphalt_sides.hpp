// Ground asphalt's existing three-step rounded lip and closed side. Input
// endpoints/probes are still prepared by the original presentation geometry.
namespace asphalt_sides {
inline void quad(Object *tool,const std::array<Vector3,4> &points,const std::array<Vector3,4> &normals,const std::array<double,4> &shades) {
    std::array<int,6> order{0,2,1,0,3,2};
    if ((points[2]-points[0]).cross(points[1]-points[0]).dot(normals[0]+normals[1]+normals[2])<0.0f) order={0,1,2,0,2,3};
    for (int i:order) {
        road_geometry::set_normal(tool,normals[i]);
        road_geometry::set_color(tool,Color(1,1,1,real_t(shades[i])));
        road_geometry::set_uv(tool,Vector2());road_geometry::set_uv2(tool,Vector2(1,0));
        road_geometry::add_vertex(tool,points[i]);
    }
}
inline bool emit(Object *tool,const PackedVector3Array &ends,const PackedVector3Array &outwards,double bottom) {
    if (!tool || ends.size()%2 || ends.size()!=outwards.size()) return false;
    // Validate before emitting anything so false always permits scalar replay.
    for (int i=0;i<ends.size();++i) if (!ends[i].is_finite() || !outwards[i].is_finite()) return false;
    struct Profile {double d0,d1,y0,y1,sin0,sin1,cos0,cos1,shade0,shade1;};
    std::array<Profile,3> profile;
    for (int step=0;step<3;++step) {
        double first=3.14159265358979323846*0.5*step/3,last=3.14159265358979323846*0.5*(step+1)/3;
        double s0=std::sin(first),s1=std::sin(last),c0=std::cos(first),c1=std::cos(last);
        profile[step]={0.005*s0,0.005*s1,0.005*(c0-1.0),0.005*(c1-1.0),s0,s1,c0,c1,0.80+(1.0-0.80)*c0,0.80+(1.0-0.80)*c1};
    }
    const Vector3 up(0,1,0);
    for (int i=0;i<ends.size();i+=2) {
        Vector3 a=ends[i],b=ends[i+1],oa=outwards[i],ob=outwards[i+1];
        Vector3 na=oa.normalized(),nb=ob.normalized();
        for (const Profile &p:profile) {
            Vector3 na0=(na*real_t(p.sin0)+up*real_t(p.cos0)).normalized(),nb0=(nb*real_t(p.sin0)+up*real_t(p.cos0)).normalized();
            Vector3 na1=(na*real_t(p.sin1)+up*real_t(p.cos1)).normalized(),nb1=(nb*real_t(p.sin1)+up*real_t(p.cos1)).normalized();
            quad(tool,{a+oa*real_t(p.d0)+up*real_t(p.y0),b+ob*real_t(p.d0)+up*real_t(p.y0),b+ob*real_t(p.d1)+up*real_t(p.y1),a+oa*real_t(p.d1)+up*real_t(p.y1)},
                {na0,nb0,nb1,na1},{p.shade0,p.shade0,p.shade1,p.shade1});
        }
        Vector3 pa=a+oa*real_t(0.005)-up*real_t(0.005),pb=b+ob*real_t(0.005)-up*real_t(0.005);
        quad(tool,{pa,pb,Vector3(pb.x,real_t(bottom),pb.z),Vector3(pa.x,real_t(bottom),pa.z)},{na,nb,nb,na},{0.80,0.80,0.80,0.80});
    }
    return true;
}
}
