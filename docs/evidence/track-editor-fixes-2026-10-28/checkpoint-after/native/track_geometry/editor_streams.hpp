// Original exact ports of the editor's stream-copy loops. No GPU resources.
#include <godot_cpp/variant/packed_byte_array.hpp>
namespace editor_streams {
template<class Packed> Variant select(const Variant &input,const std::vector<int> &indices,int stride) {
    Packed source=input, output; output.resize(int64_t(indices.size())*stride);
    auto *destination=output.ptrw(); const auto *values=source.ptr();
    int64_t cursor=0;
    for (int index:indices) for (int component=0;component<stride;++component)
        destination[cursor++]=values[int64_t(index)*stride+component];
    return output;
}
inline int length(const Variant &value) {
    switch(value.get_type()) {
        case Variant::PACKED_VECTOR3_ARRAY:return PackedVector3Array(value).size();
        case Variant::PACKED_VECTOR2_ARRAY:return PackedVector2Array(value).size();
        case Variant::PACKED_COLOR_ARRAY:return PackedColorArray(value).size();
        case Variant::PACKED_FLOAT32_ARRAY:return PackedFloat32Array(value).size();
        case Variant::PACKED_FLOAT64_ARRAY:return PackedFloat64Array(value).size();
        case Variant::PACKED_INT32_ARRAY:return PackedInt32Array(value).size();
        case Variant::PACKED_BYTE_ARRAY:return PackedByteArray(value).size();
        default:return -1;
    }
}
inline Variant copy(const Variant &value,const std::vector<int> &indices,int stride) {
    switch(value.get_type()) {
        case Variant::PACKED_VECTOR3_ARRAY:return select<PackedVector3Array>(value,indices,stride);
        case Variant::PACKED_VECTOR2_ARRAY:return select<PackedVector2Array>(value,indices,stride);
        case Variant::PACKED_COLOR_ARRAY:return select<PackedColorArray>(value,indices,stride);
        case Variant::PACKED_FLOAT32_ARRAY:return select<PackedFloat32Array>(value,indices,stride);
        case Variant::PACKED_FLOAT64_ARRAY:return select<PackedFloat64Array>(value,indices,stride);
        case Variant::PACKED_INT32_ARRAY:return select<PackedInt32Array>(value,indices,stride);
        case Variant::PACKED_BYTE_ARRAY:return select<PackedByteArray>(value,indices,stride);
        default:return Variant();
    }
}
inline Array split(const Array &arrays,double tile_size) {
    if (arrays.size()!=13 || arrays[0].get_type()!=Variant::PACKED_VECTOR3_ARRAY || !(tile_size>0)) return {};
    PackedVector3Array vertices=arrays[0];
    if (vertices.is_empty()) return {};
    PackedInt32Array indices;
    if (arrays[12].get_type()==Variant::PACKED_INT32_ARRAY) indices=arrays[12];
    bool indexed=!indices.is_empty(); int count=indexed?indices.size():vertices.size();
    if (count%3!=0) return {};
    for (int channel=0;channel<12;++channel) {
        if (arrays[channel].get_type()==Variant::NIL) continue;
        int size=length(arrays[channel]);
        if (size<0 || size%vertices.size()!=0) return {};
    }
    std::map<std::pair<int,int>,int> lookup;
    std::vector<std::vector<int>> tiles;
    for (int first=0;first<count;first+=3) {
        Vector3 center;
        for (int cursor=first;cursor<first+3;++cursor) {
            int index=indexed?indices[cursor]:cursor;
            if (index<0 || index>=vertices.size()) return {};
            center+=vertices[index];
        }
        center/=3.0f;
        std::pair<int,int> tile{int(std::floor(double(center.x)/tile_size)),int(std::floor(double(center.z)/tile_size))};
        auto found=lookup.find(tile); int slot;
        if (found==lookup.end()) {slot=tiles.size();lookup[tile]=slot;tiles.emplace_back();}
        else slot=found->second;
        for (int cursor=first;cursor<first+3;++cursor) tiles[slot].push_back(indexed?indices[cursor]:cursor);
    }
    Array result;
    for (const auto &tile:tiles) for (size_t first=0;first<tile.size();first+=12288) {
        std::vector<int> selected; PackedInt32Array mapped; std::map<int,int> remap;
        for (size_t cursor=first;cursor<std::min(first+12288,tile.size());++cursor) {
            int original=tile[cursor];
            if (!indexed) {selected.push_back(original);continue;}
            auto found=remap.find(original); int slot;
            if (found==remap.end()) {slot=selected.size();remap[original]=slot;selected.push_back(original);}
            else slot=found->second;
            mapped.append(slot);
        }
        Array part;part.resize(13);
        for (int channel=0;channel<12;++channel) if (arrays[channel].get_type()!=Variant::NIL)
            part[channel]=copy(arrays[channel],selected,length(arrays[channel])/vertices.size());
        if (indexed) part[12]=mapped;
        result.append(part);
    }
    return result;
}
inline bool append(Object *tool,const Array &arrays) {
    if (!tool || arrays.size()!=13 || arrays[0].get_type()!=Variant::PACKED_VECTOR3_ARRAY) return false;
    PackedVector3Array vertices=arrays[0], normals;
    PackedVector2Array uv,uv2;PackedColorArray colors;PackedInt32Array indices;
    if (arrays[1].get_type()==Variant::PACKED_VECTOR3_ARRAY) normals=arrays[1];
    if (arrays[3].get_type()==Variant::PACKED_COLOR_ARRAY) colors=arrays[3];
    if (arrays[4].get_type()==Variant::PACKED_VECTOR2_ARRAY) uv=arrays[4];
    if (arrays[5].get_type()==Variant::PACKED_VECTOR2_ARRAY) uv2=arrays[5];
    if (arrays[12].get_type()==Variant::PACKED_INT32_ARRAY) indices=arrays[12];
    for (int size:{int(normals.size()),int(colors.size()),int(uv.size()),int(uv2.size())})
        if (size!=0 && size!=vertices.size()) return false;
    for (int i=0;i<indices.size();++i) if (indices[i]<0 || indices[i]>=vertices.size()) return false;
    for (int cursor=0;cursor<(indices.is_empty()?vertices.size():indices.size());++cursor) {
        int i=indices.is_empty()?cursor:indices[cursor];
        if (i<0 || i>=vertices.size()) return false;
        if (!normals.is_empty()) road_geometry::set_normal(tool,normals[i]);
        if (!uv.is_empty()) road_geometry::set_uv(tool,uv[i]);
        if (!uv2.is_empty()) road_geometry::set_uv2(tool,uv2[i]);
        if (!colors.is_empty()) road_geometry::set_color(tool,colors[i]);
        road_geometry::add_vertex(tool,vertices[i]);
    }
    return true;
}
}
