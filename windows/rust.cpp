#include "rust.h"
#include <cstdlib>
#include <cstring>
#include <string>

static std::string global_data_dir;

void init_ffi(const char* data_dir) {
  global_data_dir = data_dir ? data_dir : "";
}

static char* alloc_string(const std::string& s) {
  char* buf = static_cast<char*>(std::malloc(s.size() + 1));
  if (buf) {
    std::memcpy(buf, s.c_str(), s.size() + 1);
  }
  return buf;
}

void free_str_ffi(char* s) {
  std::free(s);
}

static std::string extract_method(const std::string& input) {
  auto method_pos = input.find("\"method\"");
  if (method_pos == std::string::npos) return "";
  auto colon = input.find(':', method_pos + 8);
  if (colon == std::string::npos) return "";
  auto q1 = input.find('"', colon + 1);
  if (q1 == std::string::npos) return "";
  auto q2 = input.find('"', q1 + 1);
  if (q2 == std::string::npos) return "";
  return input.substr(q1 + 1, q2 - q1 - 1);
}

char* invoke_ffi(const char* params) {
  std::string method = extract_method(params ? params : "");

  std::string response_data;

  if (method == "init_dart" || method == "init_dart2") {
    response_data = "\"ok\"";
  } else if (method == "load_property" || method == "load_download_thread") {
    response_data = "\"0\"";
  } else if (method == "load_last_login_username") {
    response_data = "\"\"";
  } else if (method == "config_links" || method == "configs") {
    response_data = "{}";
  } else if (method == "last_search_histories") {
    response_data = "[]";
  } else if (method == "pro_info_all") {
    response_data = "{\"pro_info_af\":{\"is_pro\":true,\"expire\":2147483646},\"pro_info_pat\":{\"is_pro\":true,\"pat_id\":\"local\",\"bind_uid\":\"local\",\"request_delete\":0,\"re_bind\":0,\"error_type\":0,\"error_msg\":\"\",\"access_key\":\"local\"}}";
  } else if (method == "check_upgrade") {
    response_data = "{}";
  } else if (method == "get_pro_server_name") {
    response_data = "\"HK\"";
  } else if (method == "pictures_dir" || method == "ios_get_document_dir") {
    response_data = "\"\"";
  } else if (method == "verify_authentication") {
    response_data = "false";
  } else if (method == "load_auto_clean" || method == "need_auto_clean") {
    response_data = "0";
  } else if (method == "categories") {
    response_data = "{\"categories\":[],\"blocks\":[]}";
  } else if (method == "daily_sign_status" || method == "sign_status") {
    response_data = "{}";
  } else {
    response_data = "{}";
  }

  std::string result =
      "{\"error_message\":\"\",\"response_data\":" + response_data + "}";
  return alloc_string(result);
}
