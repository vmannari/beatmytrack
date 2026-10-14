#pragma once
#include <wincrypt.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

// User-bound DPAPI; the authentication adapter owns persistence and atomic IO.
class BmtSecureSession : public godot::RefCounted {
 GDCLASS(BmtSecureSession, godot::RefCounted)
protected:
 static void _bind_methods() {
  godot::ClassDB::bind_method(godot::D_METHOD("sealSession", "value", "context"), &BmtSecureSession::sealSession);
  godot::ClassDB::bind_method(godot::D_METHOD("openSession", "value", "context"), &BmtSecureSession::openSession);
 }
public:
 godot::PackedByteArray sealSession(const godot::String &value, const godot::String &context) {
  godot::PackedByteArray result;
  auto text=value.utf8(), entropy=context.utf8();
  if(text.length()==0 || text.length()>32768 || entropy.length()==0 || entropy.length()>4096) return result;
  DATA_BLOB input{DWORD(text.length()),reinterpret_cast<BYTE*>(const_cast<char*>(text.get_data()))};
  DATA_BLOB additional{DWORD(entropy.length()),reinterpret_cast<BYTE*>(const_cast<char*>(entropy.get_data()))};
  DATA_BLOB output{};
  if(CryptProtectData(&input,L"BMT session",&additional,nullptr,nullptr,CRYPTPROTECT_UI_FORBIDDEN,&output)) {
   result.resize(output.cbData);
   memcpy(result.ptrw(),output.pbData,output.cbData);
   SecureZeroMemory(output.pbData,output.cbData);LocalFree(output.pbData);
  }
  return result;
 }
 godot::String openSession(const godot::PackedByteArray &value, const godot::String &context) {
  if(value.is_empty() || value.size()>65536 || context.is_empty()) return {};
  auto entropy=context.utf8();
  DATA_BLOB input{DWORD(value.size()),const_cast<BYTE*>(value.ptr())};
  DATA_BLOB additional{DWORD(entropy.length()),reinterpret_cast<BYTE*>(const_cast<char*>(entropy.get_data()))};
  DATA_BLOB output{};
  godot::String result;
  if(CryptUnprotectData(&input,nullptr,&additional,nullptr,nullptr,CRYPTPROTECT_UI_FORBIDDEN,&output)) {
   if(output.cbData<=32768) result=godot::String::utf8(reinterpret_cast<char*>(output.pbData),output.cbData);
   SecureZeroMemory(output.pbData,output.cbData);LocalFree(output.pbData);
  }
  return result;
 }
};
