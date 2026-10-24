// Original ordered LooseTyres solver, with retained compact native scratch.
// Scalar arithmetic is double; Vector2 operations retain Godot's float boundary.
#include <map>
#include <vector>
#include <godot_cpp/core/math.hpp>

class BmtTyreContacts : public RefCounted {
    GDCLASS(BmtTyreContacts, RefCounted)
    struct Pair { int a,b; Vector2 delta,normal; bool touching; };
    std::vector<Vector2> points,velocities,normals,displaced;
    std::vector<double> friction;
    std::vector<Pair> pairs;
    std::map<std::pair<int,int>,std::vector<int>> buckets;
    std::vector<int> candidates;
    bool prepared=false,separated=true,geometry_ready=false;
    int64_t rebuilds=0;
    PackedInt32Array contact_cells;
    Vector2 contact_extent;
    double contact_step=0;
    int contact_width=0,contact_height=0;
    int64_t clear_queries=0,full_queries=0;
    Vector3 query(const Callable &contact,const Vector2 &point) {
        if (contact_step>0) {
            int x=int(std::floor((double(point.x)+contact_extent.x)/contact_step));
            int y=int(std::floor((double(contact_extent.y)-point.y)/contact_step));
            int reach=int(std::ceil(0.5/contact_step))+1;
            if (x-reach>=0 && x+reach<contact_width && y-reach>=0 && y+reach<contact_height) {
                bool empty=true;
                for (int row=y-reach;row<=y+reach && empty;++row) for (int column=x-reach;column<=x+reach;++column) {
                    if (contact_cells[int64_t(row)*contact_width+column]==4) {empty=false;break;}
                }
                if (empty) {++clear_queries;return Vector3();}
            }
        }
        ++full_queries;return contact.call(point,0.5,false);
    }
    static constexpr double TAU=6.283185307179586476925286766559;
    static std::pair<int,int> cell(const Vector2 &p) {
        return {int(std::floor(double(p.x)/1.6)),int(std::floor(double(p.y)/1.6))};
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("algorithm_version"),&BmtTyreContacts::algorithm_version);
        ClassDB::bind_method(D_METHOD("step_grid","bodies","car","contact","previous","geometry","world"),&BmtTyreContacts::step);
        ClassDB::bind_method(D_METHOD("work_stats"),&BmtTyreContacts::work_stats);
    }
public:
    int64_t algorithm_version() const { return 2; }
    Dictionary work_stats() const {
        Dictionary d; d["bodies"]=int64_t(points.size());d["pairs"]=int64_t(pairs.size());d["rebuilds"]=rebuilds;
        d["scratch_bytes"]=int64_t((points.capacity()+velocities.capacity()+normals.capacity()+displaced.capacity())*sizeof(Vector2)+friction.capacity()*sizeof(double)+pairs.capacity()*sizeof(Pair)+candidates.capacity()*sizeof(int));
        d["clear_queries"]=clear_queries;d["full_queries"]=full_queries;
        return d;
    }
    bool step(const Array &bodies,Array car,const Callable &contact,const Vector2 &previous,Object *geometry,const Dictionary &world) {
        const int count=int(bodies.size());
        // Reject unsupported packets before touching canonical values. The
        // script fallback retains the original behavior for unusual callers.
        if (!geometry || !contact.is_valid() || car.size()!=9 || count<1 || count>4096) return false;
        for (int i=0;i<count;++i) if (bodies[i].get_type()!=Variant::ARRAY || Array(bodies[i]).size()!=5) return false;
        contact_cells=world.get("cells",PackedInt32Array());contact_extent=world.get("extent",Vector2());
        contact_width=world.get("width",0);contact_height=world.get("height",0);contact_step=world.get("step",0.0);
        clear_queries=0;full_queries=0;
        if (contact_width<=0 || contact_height<=0 || int64_t(contact_width)*contact_height!=contact_cells.size() || !std::isfinite(contact_step) || contact_step<0.001 || !contact_extent.is_finite()) contact_step=0;
        const bool static_grid=contact_step>0;
        Vector2 position=car[0],velocity=car[1],impulse_sum=car[2],forward=car[3];
        const bool elevated=car[4]; const double mass=car[5],radius=car[6],dt=car[7]; int64_t collisions=car[8];
        bool rebuild=!prepared || int(points.size())!=count,active=false;
        points.resize(count);velocities.resize(count);normals.resize(count);friction.resize(count);
        if (static_grid) displaced.resize(count);
        std::fill(normals.begin(),normals.end(),Vector2());
        for (int i=0;i<count;++i) {
            Array row=bodies[i];Vector2 p{float(double(row[0])),float(double(row[1]))};
            if (p!=points[i]) rebuild=true;
            points[i]=p;velocities[i]=Vector2(float(double(row[2])),float(double(row[3]))).limit_length(30);
            if (velocities[i]!=Vector2()) active=true;
            friction[i]=24.0*dt;
        }
        if (rebuild) {
            ++rebuilds;prepared=true;separated=true;geometry_ready=false;buckets.clear();pairs.clear();
            for (int i=0;i<count;++i) {
                auto key=cell(points[i]);
                // Exactly the script's index / neighbour / insertion order.
                for (int y=-1;y<=1;++y) for (int x=-1;x<=1;++x) {
                    auto found=buckets.find({key.first+x,key.second+y});
                    if (found==buckets.end()) continue;
                    for (int other:found->second) if (double(points[i].distance_squared_to(points[other]))<=1.6*1.6) {
                        Vector2 delta=points[i]-points[other];
                        pairs.push_back({other,i,Vector2(),Vector2(),false});
                        if (double(delta.length())<1.0) separated=false;
                    }
                }
                buckets[key].push_back(i);
            }
        }
        candidates.clear();
        if (!elevated) {
            double reach=radius+0.5+0.005+0.0001;
            Vector2 lo=(previous.min(position)-Vector2(1,1)*float(reach))/float(1.6);
            Vector2 hi=(previous.max(position)+Vector2(1,1)*float(reach))/float(1.6);
            int x0=int(std::floor(lo.x)),y0=int(std::floor(lo.y)),x1=int(std::floor(hi.x)),y1=int(std::floor(hi.y));
            if (int64_t(x1-x0+1)*(y1-y0+1)<=64) {
                for (int y=y0;y<=y1;++y) for (int x=x0;x<=x1;++x) {
                    auto found=buckets.find({x,y}); if (found==buckets.end()) continue;
                    candidates.insert(candidates.end(),found->second.begin(),found->second.end());
                }
                std::sort(candidates.begin(),candidates.end());
            } else for (int i=0;i<count;++i) candidates.push_back(i);
        }
        for (int i:candidates) {
            Vector2 near=geometry->call("get_closest_point_to_segment",points[i],previous,position);
            Vector2 delta=points[i]-near;
            if (double(delta.length())<=radius+0.5+0.005) normals[i]=double(delta.length_squared())>0.000001?delta.normalized():forward;
            if (normals[i]!=Vector2()) active=true;
        }
        if (!active && separated) {
            for (int i=0;i<count;++i) {Array row=bodies[i];row[4]=Math::fposmod(double(row[4]),TAU);}
            return true;
        }
        if (!geometry_ready) {
            for (Pair &pair:pairs) {
                pair.delta=points[pair.b]-points[pair.a];
                pair.normal=double(pair.delta.length_squared())>0.000001?pair.delta.normalized():Vector2(1,0);
                pair.touching=double(pair.delta.length())<=1.005;
            }
            geometry_ready=true;
        }
        for (int iteration=0;iteration<(active?16:0);++iteration) {
            for (int i=0;i<count;++i) {
                if (velocities[i]==Vector2() && normals[i]==Vector2()) continue;
                double speed=velocities[i].length(),reduction=std::min(speed,friction[i]);
                velocities[i]=velocities[i].move_toward(Vector2(),float(reduction));friction[i]-=reduction;
                Vector2 normal=normals[i];if (normal==Vector2()) continue;
                double approach=(velocity-velocities[i]).dot(normal);
                if (approach>0) {
                    double impulse=approach/(1.0/mass+1.0/400.0);
                    velocity-=normal*float(impulse)/float(mass);impulse_sum-=normal*float(impulse)/float(mass);
                    velocities[i]+=normal*float(impulse)/float(400.0);
                    if (iteration==0) ++collisions;
                }
            }
            for (const Pair &pair:pairs) {
                if (velocities[pair.a]==Vector2() && velocities[pair.b]==Vector2()) continue;
                if (!pair.touching && double((pair.delta+(velocities[pair.b]-velocities[pair.a])*float(dt)).length())>1.0) continue;
                double approach=(velocities[pair.a]-velocities[pair.b]).dot(pair.normal);
                if (approach>0) {velocities[pair.a]-=pair.normal*float(approach)*float(0.5);velocities[pair.b]+=pair.normal*float(approach)*float(0.5);}
            }
        }
        for (int i=0;i<count;++i) {
            Array row=bodies[i];Vector2 p=points[i],v=velocities[i],motion=v*float(dt);
            int steps=v==Vector2()?0:std::max(1,int(std::ceil(double(motion.length())/0.2)));
            for (int j=0;j<steps;++j) {
                Vector2 next=p+motion/float(steps);Vector3 hit=query(contact,next);
                if (hit.z>0) {v=Vector2();break;} p=next;
            }
            if (!elevated) {
                Vector2 delta=p-position;double reach=radius+0.5;
                if (double(delta.length())<reach) position=p-(double(delta.length_squared())>0.000001?delta.normalized():forward)*float(reach);
            }
            row[0]=double(p.x);row[1]=double(p.y);row[2]=double(v.x);row[3]=double(v.y);
            row[4]=Math::fposmod(double(row[4])+double(v.length())*dt/0.5,TAU);
            if (static_grid) displaced[i]=p;
        }
        for (int iteration=0;iteration<4;++iteration) {
            for (const Pair &pair:pairs) {
                Vector2 pa,pb;
                if (static_grid) {pa=displaced[pair.a];pb=displaced[pair.b];}
                else {
                    Array a=bodies[pair.a],b=bodies[pair.b];
                    pa=Vector2(float(double(a[0])),float(double(a[1])));pb=Vector2(float(double(b[0])),float(double(b[1])));
                }
                Vector2 delta=pb-pa;if (double(delta.length())>=1.0) continue;
                Vector2 normal=double(delta.length_squared())>0.000001?delta.normalized():Vector2(1,0);
                Vector2 correction=normal*float(1.0-double(delta.length()))*float(0.5);
                Vector2 next_a=pa-correction,next_b=pb+correction;
                if (next_a!=pa && query(contact,next_a).z<=0) pa=next_a;
                if (next_b!=pb && query(contact,next_b).z<=0) pb=next_b;
                if (static_grid) {displaced[pair.a]=pa;displaced[pair.b]=pb;}
                else {Array a=bodies[pair.a],b=bodies[pair.b];a[0]=double(pa.x);a[1]=double(pa.y);b[0]=double(pb.x);b[1]=double(pb.y);}
            }
            if (elevated) continue;
            for (int i=0;i<count;++i) {
                Vector2 p;
                if (static_grid) p=displaced[i];
                else {Array row=bodies[i];p=Vector2(float(double(row[0])),float(double(row[1])));}
                Vector2 delta=p-position;
                double reach=radius+0.5;
                if (double(delta.length())<reach) position=p-(double(delta.length_squared())>0.000001?delta.normalized():forward)*float(reach);
            }
        }
        // The certified base-grid query never reads tyre state. Keep the
        // ordered corrections compact, then publish exact float->double rows.
        // Custom callbacks retain their original eager row updates above.
        if (static_grid) for (int i=0;i<count;++i) {Array row=bodies[i];row[0]=double(displaced[i].x);row[1]=double(displaced[i].y);}
        car[0]=position;car[1]=velocity;car[2]=impulse_sum;car[8]=collisions;
        return true;
    }
};
