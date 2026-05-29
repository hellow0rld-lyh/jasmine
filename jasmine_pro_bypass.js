// Jasmine Pro Bypass — Frida hook script
// Usage: frida -U -f opensource.jmtt2mic -l jasmine_pro_bypass.js

function main() {
  console.log("[+] Jasmine Pro Bypass loaded");

  var moduleName = "librust.so";

  // 等 librust.so 加载完成
  var module = Process.findModuleByName(moduleName);
  if (!module) {
    console.log("[-] librust.so not found, waiting for load...");
    return;
  }

  var invokePtr = Module.findExportByName(moduleName, "invoke_ffi");
  if (!invokePtr) {
    console.log("[-] invoke_ffi export not found, trying alternatives...");
    ["_Z10invoke_ffiPKc", "invoke", "Java_"].forEach(function(name) {
      var p = Module.findExportByName(moduleName, name);
      if (p) { invokePtr = p; console.log("[+] Found: " + name); }
    });
  }

  if (!invokePtr) {
    console.log("[-] invoke_ffi not found");
    return;
  }

  console.log("[+] invoke_ffi at " + invokePtr);

  Interceptor.attach(invokePtr, {
    onEnter: function(args) {
      this.params = args[0] ? Memory.readCString(args[0]) : "";
      try {
        this.method = JSON.parse(this.params).method || "";
      } catch (e) { this.method = ""; }
    },
    onLeave: function(retval) {
      if (!this.method) return;

      var blocked = null;

      if (this.method === "pro_info_all") {
        blocked = JSON.stringify({
          error_message: "",
          response_data: JSON.stringify({
            pro_info_af: { is_pro: true, expire: 2147483646 },
            pro_info_pat: { is_pro: true, pat_id: "local", bind_uid: "local",
              request_delete: 0, re_bind: 0, error_type: 0, error_msg: "",
              access_key: "local" }
          })
        });
      }
      else if (this.method === "is_pro") {
        blocked = JSON.stringify({
          error_message: "",
          response_data: JSON.stringify({ is_pro: true, expire: 2147483646 })
        });
      }
      else if (["reload_pro", "reload_pat_account", "input_cd_key",
                "check_pat", "clear_pat", "daily_sign_status",
                "sign_status"].indexOf(this.method) !== -1) {
        blocked = JSON.stringify({ error_message: "", response_data: "\"ok\"" });
      }
      else if (this.method === "check_upgrade") {
        blocked = JSON.stringify({ error_message: "", response_data: "{}" });
      }
      else if (this.method === "get_pro_server_name") {
        blocked = JSON.stringify({ error_message: "", response_data: "\"HK\"" });
      }

      if (blocked) {
        console.log("[✓] " + this.method + " → blocked");
        retval.replace(Memory.allocUtf8String(blocked));
      }
    }
  });

  console.log("[+] Hook installed. Pro bypass active.");
}

setTimeout(function() {
  Java.perform(function () { main(); });
}, 1000);
