import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:jasmine/basic/comic_seal.dart';
import 'package:jasmine/basic/log.dart';

import 'entities.dart';

export 'entities.dart';

const methods = Methods._();

class Methods {
  const Methods._();

  static const _channel = MethodChannel("methods");
  static HttpClient httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  // Local property store (replaces Rust backend persistence)
  static final Map<String, String> _props = {};
  static String _dataDir = '';
  static bool _propsLoaded = false;
  static String get _propsPath => '$_dataDir/properties.json';

  Future<String> _invoke(String method, dynamic params) async {
    final paramsStr = params is String ? params : jsonEncode(params);

    switch (method) {
      // === Init - create data directory ===
      case 'init_dart':
      case 'init_dart2':
        await _ensureDataDir();
        return jsonEncode("ok");

      // === Property storage ===
      case 'load_property':
        return (await _loadProperty(paramsStr)) ?? "";
      case 'save_property': {
        final p = params is Map ? params : jsonDecode(paramsStr);
        await _saveProperty('${p['k']}', '${p['v']}');
        return jsonEncode("ok");
      }
      case 'delete_property':
        await _deleteProperty(paramsStr);
        return jsonEncode("ok");

      // === Config / app config / upgrade check ===
      case 'config_links':
      case 'configs':
      case 'app_config':
      case 'check_upgrade':
        return "{}";

      // === Startup image (not persisted without Rust) ===
      case 'get_startup_image_path':
        return jsonEncode("");
      case 'save_startup_image':
      case 'delete_startup_image':
        return jsonEncode("ok");

      // === Search history ===
      case 'last_search_histories':
        return jsonEncode([]);
      case 'clear_all_search_log':
      case 'clear_a_search_log':
        return jsonEncode("ok");

      // === Pro methods (all bypassed as sponsor) ===
      case 'is_pro':
        return jsonEncode({"is_pro": true, "expire": 2147483646});
      case 'pro_info_all':
        return jsonEncode({
          "pro_info_af": {"is_pro": true, "expire": 2147483646},
          "pro_info_pat": {
            "is_pro": true,
            "pat_id": "local",
            "bind_uid": "local",
            "request_delete": 0,
            "re_bind": 0,
            "error_type": 0,
            "error_msg": "",
            "access_key": "local"
          }
        });
      case 'reload_pro':
      case 'reload_pat_account':
      case 'input_cd_key':
      case 'check_pat':
      case 'clear_pat':
        return jsonEncode("ok");
      case 'bind_pat': {
        final p = params is Map ? params : jsonDecode(paramsStr);
        await _saveProperty('pat_access_key', '${p['access_key']}');
        await _saveProperty('pat_username', '${p['username']}');
        return jsonEncode("ok");
      }
      case 'get_pro_server_name':
        return jsonEncode(await _loadProperty('pro_server_name') ?? "HK");
      case 'set_pro_server_name':
        await _saveProperty('pro_server_name', paramsStr);
        return jsonEncode("ok");
      case 'daily_sign_status':
      case 'sign_status':
        return "{}";

      // === Login credentials ===
      case 'load_username':
        return jsonEncode(await _loadProperty('username') ?? "");
      case 'load_password':
        return jsonEncode(await _loadProperty('password') ?? "");
      case 'load_last_login_username':
        return jsonEncode(await _loadProperty('last_login_username') ?? "");

      // === API / CDN host ===
      case 'load_api_host':
        return jsonEncode(await _loadProperty('api_host') ?? "");
      case 'save_api_host':
        await _saveProperty('api_host', paramsStr);
        return jsonEncode("ok");
      case 'load_cdn_host':
        return jsonEncode(await _loadProperty('cdn_host') ?? "");
      case 'save_cdn_host':
        await _saveProperty('cdn_host', paramsStr);
        return jsonEncode("ok");

      // === Download thread config ===
      case 'load_download_thread':
        return jsonEncode(await _loadProperty('download_thread') ?? "0");
      case 'set_download_thread':
        await _saveProperty('download_thread', paramsStr);
        return jsonEncode("ok");

      // === Auto clean ===
      case 'load_auto_clean':
      case 'need_auto_clean':
        return jsonEncode(await _loadProperty('auto_clean') ?? "0");

      // === Proxy ===
      case 'set_proxy':
        await _saveProperty('proxy', paramsStr);
        return jsonEncode("ok");
      case 'get_proxy':
        return jsonEncode(await _loadProperty('proxy') ?? "");

      // === Download / export directory ===
      case 'get_download_and_export_to':
        return jsonEncode(await _loadProperty('download_and_export_to') ?? "");
      case 'set_download_and_export_to':
        await _saveProperty('download_and_export_to', paramsStr);
        return jsonEncode("ok");
      case 'getHomeDir':
        return jsonEncode(Directory.current.path);

      // === Directory creation ===
      case 'mkdirs':
        try {
          Directory(paramsStr).createSync(recursive: true);
          return jsonEncode("ok");
        } catch (e) {
          return jsonEncode("error: $e");
        }

      // === Copy picture ===
      case 'copyPictureToFolder': {
        final p = params is Map ? params : jsonDecode(paramsStr);
        try {
          final src = File('${p['path']}');
          final name = src.uri.pathSegments.last;
          await src.copy('${p['folder']}/$name');
          return jsonEncode('${p['folder']}/$name');
        } catch (e) {
          return jsonEncode("");
        }
      }

      // === Image dimensions (parse JPEG/PNG headers) ===
      case 'image_size': {
        try {
          final file = File(paramsStr);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            int w = 0, h = 0;
            if (bytes.length >= 2) {
              if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
                final dims = _parseJpegSize(bytes);
                w = dims[0];
                h = dims[1];
              } else if (bytes[0] == 0x89 && bytes[1] == 0x50) {
                // PNG
                if (bytes.length >= 24) {
                  w = (bytes[16] << 24) |
                      (bytes[17] << 16) |
                      (bytes[18] << 8) |
                      bytes[19];
                  h = (bytes[20] << 24) |
                      (bytes[21] << 16) |
                      (bytes[22] << 8) |
                      bytes[23];
                }
              }
            }
            return jsonEncode({"w": w, "h": h});
          }
        } catch (_) {}
        return jsonEncode({"w": 0, "h": 0});
      }

      // === HTTP GET ===
      case 'http_get': {
        try {
          final req = await httpClient.getUrl(Uri.parse(paramsStr));
          final rsp = await req.close();
          return await rsp.transform(utf8.decoder).join();
        } catch (e) {
          return jsonEncode("");
        }
      }

      // === Clean cache ===
      case 'clean_all_cache':
        return "{}";

      // === Image URL construction + cache download ===
      case 'jm_3x4_cover': {
        final id = params is int ? params : int.tryParse(paramsStr) ?? 0;
        final host = await _getCdnHost();
        return jsonEncode(
            await _cacheImage("https://$host/media/album/${id}_3x4.jpg", "c34_$id"));
      }
      case 'jm_square_cover': {
        final id = params is int ? params : int.tryParse(paramsStr) ?? 0;
        final host = await _getCdnHost();
        return jsonEncode(
            await _cacheImage("https://$host/media/album/$id.jpg", "csq_$id"));
      }
      case 'jm_page_image': {
        final p = params is Map ? params : jsonDecode(paramsStr);
        final host = await _getCdnHost();
        return jsonEncode(await _cacheImage(
            "https://$host/media/${p['id']}/${p['image_name']}",
            "page_${p['id']}_${p['image_name']}"));
      }
      case 'jm_photo_image': {
        final host = await _getCdnHost();
        return jsonEncode(await _cacheImage(
            "https://$host/media/photos/$paramsStr", "ph_$paramsStr"));
      }
      case 'delete_jm_page_image_cache': {
        final p = params is Map ? params : jsonDecode(paramsStr);
        final f =
            File('$_dataDir/cache/page_${p['id']}_${p['image_name']}');
        if (await f.exists()) await f.delete();
        return jsonEncode("ok");
      }

      // === View log ===
      case 'clear_view_log':
        return jsonEncode("ok");

      // === WebDAV ===
      case 'sync_webdav':
        return jsonEncode("ok");

      // === Ping (actually measure latency) ===
      case 'ping_server':
      case 'ping_cdn': {
        try {
          final sw = Stopwatch()..start();
          final req = await httpClient.getUrl(Uri.parse("https://$paramsStr/"));
          await req.close();
          sw.stop();
          return jsonEncode("${sw.elapsedMilliseconds}");
        } catch (_) {
          return jsonEncode("99999");
        }
      }

      // === Export / import (not available without Rust) ===
      case 'export_jm_jpegs':
      case 'export_jm_zip':
      case 'export_jm_zip_single':
      case 'export_jm_jpegs_zip_single':
      case 'export_jm_jmi':
      case 'export_jm_jmi_single':
      case 'export_cbzs_zip_single':
      case 'export_jm_pdf':
      case 'export_jm_pdf2':
      case 'export_jm_epub':
      case 'export_jm_epub_single':
      case 'import_jm_zip':
      case 'import_jm_jmi':
      case 'import_jm_dir':
        throw StateError("导出/导入功能在纯Dart模式下不可用");

      // === Default: forward to remote API host ===
      default:
        return await _forwardToApi(method, paramsStr);
    }
  }

  // ---- Private backend helpers ----

  Future<void> _ensureDataDir() async {
    if (_propsLoaded) return;
    _dataDir = '${Directory.current.path}/.jasmine';
    await Directory(_dataDir).create(recursive: true);
    final f = File(_propsPath);
    if (await f.exists()) {
      try {
        final d = jsonDecode(await f.readAsString());
        if (d is Map) {
          d.forEach((k, v) => _props['$k'] = '$v');
        }
      } catch (_) {}
    }
    _propsLoaded = true;
  }

  Future<String?> _loadProperty(String key) async {
    if (!_propsLoaded) await _ensureDataDir();
    return _props[key];
  }

  Future<void> _saveProperty(String key, String value) async {
    if (!_propsLoaded) await _ensureDataDir();
    _props[key] = value;
    await File(_propsPath).writeAsString(jsonEncode(_props));
  }

  Future<void> _deleteProperty(String key) async {
    if (!_propsLoaded) await _ensureDataDir();
    _props.remove(key);
    await File(_propsPath).writeAsString(jsonEncode(_props));
  }

  Future<String> _getCdnHost() async {
    final saved = await _loadProperty('cdn_host');
    if (saved != null && saved.isNotEmpty) return saved;
    return 'cdn-msp3.jmdanjonproxy.vip';
  }

  Future<String> _getApiHost() async {
    final saved = await _loadProperty('api_host');
    if (saved != null && saved.isNotEmpty) return saved;
    return 'www.cdnbea.net';
  }

  /// Download an image from [url] to a local cache file keyed by [key].
  /// Returns the local file path (or the original URL as fallback).
  Future<String> _cacheImage(String url, String key) async {
    await _ensureDataDir();
    final dir = Directory('$_dataDir/cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    final f = File('${dir.path}/$key');
    if (await f.exists()) return f.path;
    try {
      final req = await httpClient.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      final rsp = await req.close();
      if (rsp.statusCode == 200) {
        final bytes = (await rsp.toList()).expand((c) => c).toList();
        await f.writeAsBytes(bytes);
        return f.path;
      }
    } catch (_) {}
    return url;
  }

  /// Forward a method call to the remote API host (same protocol as Rust backend).
  Future<String> _forwardToApi(String method, String paramsStr) async {
    final host = await _getApiHost();
    final body = utf8.encode(jsonEncode({
      "method": method,
      "params": paramsStr,
    }));
    // Try HTTPS first, then HTTP
    for (final proto in ['https', 'http']) {
      try {
        final req =
            await httpClient.postUrl(Uri.parse("$proto://$host/invoke"));
        req.headers.contentType = ContentType.json;
        req.headers.set('User-Agent', 'Jasmine/1.0');
        req.add(body);
        final rsp = await req.close();
        if (rsp.statusCode == 200) {
          final raw = await rsp.transform(utf8.decoder).join();
          final decoded = jsonDecode(raw);
          if (decoded is Map && decoded.containsKey('response_data')) {
            final data = decoded['response_data'];
            if (data is String) return data;
            return jsonEncode(data);
          }
          return raw;
        }
        return jsonEncode(
            {"error_message": "HTTP ${rsp.statusCode}", "response_data": "{}"});
      } catch (_) {
        continue;
      }
    }
    return jsonEncode(
        {"error_message": "连接API服务器失败: $host", "response_data": "{}"});
  }

  /// Parse JPEG dimensions from raw bytes (SOF0/SOF1/SOF2 markers).
  List<int> _parseJpegSize(List<int> bytes) {
    int offset = 2;
    while (offset + 4 < bytes.length) {
      if (bytes[offset] != 0xFF) break;
      final marker = bytes[offset + 1];
      if (marker >= 0xC0 && marker <= 0xC3) {
        if (offset + 9 < bytes.length) {
          final h = (bytes[offset + 5] << 8) | bytes[offset + 6];
          final w = (bytes[offset + 7] << 8) | bytes[offset + 8];
          return [w, h];
        }
        break;
      }
      if (marker == 0xD9 || marker == 0xDA) break;
      if (offset + 4 >= bytes.length) break;
      final segLen = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (segLen < 2) break;
      offset += segLen + 2;
    }
    return [0, 0];
  }

  Future init() {
    return _invoke("init_dart", "");
  }

  Future init2() {
    return _invoke("init_dart2", "");
  }

  Future<Map<String, String>> configLinks() async {
    final rsp = await _invoke("config_links", "");
    final decoded = jsonDecode(rsp);
    if (decoded is! Map) {
      return {};
    }
    return decoded.map((key, value) => MapEntry("$key", "$value"));
  }

  Future<Map<String, dynamic>> appConfig() async {
    final rsp = await _invoke("app_config", "");
    final decoded = jsonDecode(rsp);
    if (decoded is! Map) {
      return {};
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<String> loadProperty(String propertyKey) {
    return _invoke("load_property", propertyKey);
  }

  Future<String> getStartupImagePath() {
    return _invoke("get_startup_image_path", "");
  }

  Future saveStartupImage(String base64Data) {
    return _invoke("save_startup_image", base64Data);
  }

  Future deleteStartupImage() {
    return _invoke("delete_startup_image", "");
  }

  Future<ComicsResponse> comics(String slug, SortBy sortBy, int page) async {
    final rsp = await _invoke("comics", {
      "categories_slug": slug,
      "sort_by": sortBy.value,
      "page": page,
    });
    final response = ComicsResponse.fromJson(jsonDecode(rsp));
    for (final comic in response.content) {
      comic.sealed = matchComicSealedByRules(comic);
    }
    return response;
  }

  Future<ComicsResponse> comicSearch(
    String searchQuery,
    SortBy sortBy,
    int page,
  ) async {
    final rsp = await _invoke("comic_search", {
      "search_query": searchQuery,
      "sort_by": sortBy.value,
      "page": page,
    });
    final response = ComicsResponse.fromJson(jsonDecode(rsp));
    for (final comic in response.content) {
      comic.sealed = matchComicSealedByRules(comic);
    }
    return response;
  }

  Future<ComicsResponse> pageViewLog(int page) async {
    final rsp = await _invoke("page_view_log", page);
    return ComicsResponse.fromJson(jsonDecode(rsp));
  }

  Future<dynamic> deleteViewLogByComicId(int comicId) async {
    final rsp = await _invoke("delete_view_log_by_comic_id", comicId);
    return rsp;
  }

  Future<CategoriesResponse> categories() async {
    return CategoriesResponse.fromJson(
        jsonDecode(await _invoke("categories", "")));
  }

  Future saveImageFileToGallery(String path) {
    return _channel.invokeMethod("saveImageFileToGallery", path);
  }

  Future saveProperty(String key, String v) {
    return _invoke("save_property", {"k": key, "v": v});
  }

  Future deleteProperty(String key) {
    return _invoke("delete_property", key);
  }

  Future<AlbumResponse> album(int id, {bool ignoreViewLog = false}) async {
    return AlbumResponse.fromJson(jsonDecode(await _invoke("album", {
      "id": id,
      "ignore_view_log": ignoreViewLog,
    })));
  }

  Future<ChapterResponse> chapter(int id) async {
    return ChapterResponse.fromJson(jsonDecode(await _invoke("chapter", id)));
  }

  Future<CommentPage> forum(String? mode, int? aid, int? uid, int page) async {
    return CommentPage.fromJson(jsonDecode(await _invoke("forum", {
      "mode": mode,
      "aid": aid,
      "uid": uid,
      "page": page,
    })));
  }

  Future<Favorite> favorites(int folderId, int page, String o) async {
    return Favorite.fromJson(
      jsonDecode(await _invoke("favorites", {
        "folder_id": folderId,
        "page": page,
        "o": o,
      })),
    );
  }

  Future<Favorite> favorite() async {
    return Favorite.fromJson(
      jsonDecode(await _invoke("favorite", "")),
    );
  }

  Future<ActionResponse> setFavorite(int aid) async {
    return ActionResponse.fromJson(
      jsonDecode(await _invoke("set_favorite", aid)),
    );
  }

  Future createFavoriteFolder(String name) async {
    return _invoke("create_favorite_folder", name);
  }

  Future deleteFavoriteFolder(int folderId) async {
    return _invoke("delete_favorite_folder", folderId);
  }

  Future comicFavoriteFolderMove(int comicId, int folderId) async {
    return _invoke("comic_favorite_folder_move", [comicId, folderId]);
  }

  Future renameFavoriteFolder(int folderId, String name) async {
    return _invoke("rename_favorite_folder", ["$folderId", name]);
  }

  Future<GamePage> games(int page) async {
    return GamePage.fromJson(
      jsonDecode(await _invoke("games", page)),
    );
  }

  Future updateViewLog(int id, int lastViewChapterId, int lastViewPage) {
    return _invoke("update_view_log", {
      "id": id,
      "last_view_chapter_id": lastViewChapterId,
      "last_view_page": lastViewPage,
    });
  }

  Future<ViewLog?> findViewLog(int id) async {
    final map = jsonDecode(await _invoke("find_view_log", id));
    if (map == null) {
      return null;
    }
    return ViewLog.fromJson(map);
  }

  Future cleanAllCache() async {
    return _invoke("clean_all_cache", "params");
  }

  Future<String> jm3x4Cover(int comicId) {
    return _invoke("jm_3x4_cover", comicId);
  }

  Future<String> jmSquareCover(int comicId) {
    return _invoke("jm_square_cover", comicId);
  }

  Future<String> jmPageImage(int id, String imageName) {
    return _invoke("jm_page_image", {"id": id, "image_name": imageName});
  }

  Future deleteJmPageImageCache(int id, String imageName) {
    return _invoke(
      "delete_jm_page_image_cache",
      {"id": id, "image_name": imageName},
    );
  }

  Future<String> jmPhotoImage(String imageName) {
    return _invoke("jm_photo_image", imageName);
  }

  Future<ImageSize> imageSize(String path) async {
    return ImageSize.fromJson(jsonDecode(await _invoke("image_size", path)));
  }

  Future httpGet(String versionUrl) {
    return _invoke("http_get", versionUrl);
  }

  Future<String> loadApiHost() {
    return _invoke("load_api_host", "");
  }

  Future<String> loadCdnHost() {
    return _invoke("load_cdn_host", "");
  }

  Future saveApiHost(String choose) {
    return _invoke("save_api_host", choose);
  }

  Future saveCdnHost(String choose) {
    return _invoke("save_cdn_host", choose);
  }

  Future<PreLoginResponse> preLogin() async {
    return PreLoginResponse.fromJson(
      jsonDecode(await _invoke("pre_login", "")),
    );
  }

  Future<SelfInfo> login(String username, String password) async {
    return SelfInfo.fromJson(
      jsonDecode(await _invoke("login", {
        "username": username,
        "password": password,
      })),
    );
  }

  Future logout() async {
    await _invoke("logout", {});
  }

  Future<CommentResponse> commentResponse(int aid, String comment) async {
    return CommentResponse.fromJson(jsonDecode(await _invoke("comment", {
      "aid": aid,
      "comment": comment,
    })));
  }

  Future<CommentResponse> comment(int aid, String comment) async {
    return CommentResponse.fromJson(jsonDecode(await _invoke("comment", {
      "aid": aid,
      "comment": comment,
    })));
  }

  Future<CommentResponse> childComment(
    int aid,
    String comment,
    int? commentId,
  ) async {
    return CommentResponse.fromJson(jsonDecode(await _invoke("child_comment", {
      "aid": aid,
      "comment": comment,
      "comment_id": commentId,
    })));
  }

  Future<String> loadUsername() {
    return _invoke("load_username", "");
  }

  Future<String> loadLastLoginUsername() {
    return _invoke("loadLastLoginUsername", "");
  }

  Future<String> loadPassword() {
    return _invoke("load_password", "");
  }

  Future clearViewLog() {
    return _invoke("clear_view_log", "");
  }

  Future<List<SearchHistory>> lastSearchHistories(int count) async {
    return List.of(jsonDecode(await _invoke("last_search_histories", "$count")))
        .map((e) => SearchHistory.fromJson(e))
        .toList()
        .cast<SearchHistory>();
  }

  /// 下载列表
  Future<List<DownloadAlbum>> allDownloads() async {
    return List.of(jsonDecode(await _invoke("all_downloads", "")))
        .map((e) => DownloadAlbum.fromJson(e))
        .toList()
        .cast<DownloadAlbum>();
  }

  /// 寻找下载
  Future<DownloadCreate?> downloadById(int id) async {
    var map = jsonDecode(await _invoke("download_by_id", "$id"));
    if (map == null) {
      return map;
    }
    return DownloadCreate.fromJson(map);
  }

  /// 创建下载
  Future<dynamic> createDownload(DownloadCreate create) async {
    return _invoke("create_download", create);
  }

  /// 下载图片列表
  Future<List<DlImage>> dlImageByChapterId(int id) async {
    return List.of(jsonDecode(await _invoke("dl_image_by_chapter_id", "$id")))
        .map((e) => DlImage.fromJson(e))
        .toList()
        .cast<DlImage>();
  }

  Future<dynamic> deleteDownload(int id) async {
    return _invoke("delete_download", id);
  }

  Future<dynamic> renewAllDownloads() async {
    return _invoke("renew_all_downloads", "");
  }

  /// 获取安卓的屏幕刷新率
  Future<List<String>> loadAndroidModes() async {
    return List.of(await _channel.invokeMethod("androidGetModes"))
        .map((e) => "$e")
        .toList();
  }

  /// 设置安卓的屏幕刷新率
  Future setAndroidMode(String androidDisplayMode) {
    return _channel
        .invokeMethod("androidSetMode", {"mode": androidDisplayMode});
  }

  /// 获取安卓的版本
  Future<int> androidGetVersion() async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod("androidGetVersion", {});
    }
    return 0;
  }

  Future export_jm_jpegs(List<int> idList, String path, bool deleteExported) {
    return _invoke("export_jm_jpegs", {
      "comic_id": idList,
      "dir": path,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_zip(List<int> idList, String path, bool deleteExported) {
    return _invoke("export_jm_zip", {
      "comic_id": idList,
      "dir": path,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_zip_single(
      int id, String folder, String? rename, bool deleteExported) {
    return _invoke("export_jm_zip_single", {
      "id": id,
      "folder": folder,
      "rename": rename,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_jpegs_zip_single(
      int id, String folder, String? rename, bool deleteExported) {
    return _invoke("export_jm_jpegs_zip_single", {
      "id": id,
      "folder": folder,
      "rename": rename,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_jmi(List<int> idList, String path, bool deleteExported) {
    return _invoke("export_jm_jmi", {
      "comic_id": idList,
      "dir": path,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_jmi_single(
      int id, String folder, String? rename, bool deleteExported) {
    return _invoke("export_jm_jmi_single", {
      "id": id,
      "folder": folder,
      "rename": rename,
      "delete_exported": deleteExported,
    });
  }

  Future export_cbzs_zip_single(
      int id, String folder, String? rename, bool deleteExported) {
    return _invoke("export_cbzs_zip_single", {
      "id": id,
      "folder": folder,
      "rename": rename,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_pdf(int id, String folder, bool deleteExported) {
    return _invoke("export_jm_pdf", {
      "comic_id": [id],
      "dir": folder,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_pdf2(int id, String folder, bool deleteExported) {
    return _invoke("export_jm_pdf2", {
      "comic_id": [id],
      "dir": folder,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_epub(List<int> idList, String path, bool deleteExported) {
    return _invoke("export_jm_epub", {
      "comic_id": idList,
      "dir": path,
      "delete_exported": deleteExported,
    });
  }

  Future export_jm_epub_single(
      int id, String folder, String? rename, bool deleteExported) {
    return _invoke("export_jm_epub_single", {
      "id": id,
      "folder": folder,
      "rename": rename,
      "delete_exported": deleteExported,
    });
  }

  Future import_jm_zip(String path) {
    debugPrient(path);
    return _invoke("import_jm_zip", path);
  }

  Future import_jm_jmi(String path) {
    debugPrient(path);
    return _invoke("import_jm_jmi", path);
  }

  Future import_jm_dir(String path) {
    debugPrient(path);
    return _invoke("import_jm_dir", path);
  }

  Future<IsPro> isPro() async {
    return IsPro.fromJson(jsonDecode(await _invoke("is_pro", "")));
  }

  Future<ProInfoAll> proInfoAll() async {
    return ProInfoAll.fromJson(jsonDecode(await _invoke("pro_info_all", "")));
  }

  Future reloadPro() {
    return _invoke("reload_pro", "");
  }

  Future inputCdKey(String cdKey) {
    return _invoke("input_cd_key", cdKey);
  }

  Future checkPat(String accessKey) {
    return _invoke("check_pat", accessKey);
  }

  Future bindPatAccount(String accessKey, String username) {
    return _invoke(
        "bind_pat",
        jsonEncode({
          "access_key": accessKey,
          "username": username,
        }));
  }

  Future reloadPatAccount() {
    return _invoke("reload_pat_account", "");
  }

  Future clearPat() {
    return _invoke("clear_pat", "");
  }

  Future<int> load_download_thread() async {
    return int.parse(await _invoke("load_download_thread", ""));
  }

  Future set_download_thread(int count) {
    return _invoke("set_download_thread", "$count");
  }

  Future clearAllSearchLog() {
    return _invoke("clear_all_search_log", "");
  }

  Future clearASearchLog(String log) {
    return _invoke("clear_a_search_log", log);
  }

  Future setProxy(String url) {
    return _invoke("set_proxy", url);
  }

  Future<String> getProxy() {
    return _invoke("get_proxy", "");
  }

  Future webDavSync(dynamic params) {
    return _invoke("sync_webdav", params);
  }

  Future<String> iosGetDocumentDir() async {
    return await _channel.invokeMethod("iosGetDocumentDir");
  }

  Future<String> androidDefaultExportsDir() async {
    return await _channel.invokeMethod("androidDefaultExportsDir");
  }

  Future<String> getDownloadAndExportTo() async {
    return await _invoke("get_download_and_export_to", "");
  }

  Future<String> getHomeDir() async {
    return await _invoke("getHomeDir", "");
  }

  Future setDownloadAndExportTo(String path) async {
    return await _invoke("set_download_and_export_to", path);
  }

  Future<int> ping(String idx) async {
    debugPrient("PING API $idx");
    return int.parse(await _invoke("ping_server", idx));
  }

  Future<int> pingCdn(String idx) async {
    debugPrient("PING CDN $idx");
    return int.parse(await _invoke("ping_cdn", idx));
  }

  Future mkdirs(String path) {
    return _invoke("mkdirs", path);
  }

  Future androidMkdirs(String path) async {
    return await _channel.invokeMethod("androidMkdirs", path);
  }

  Future<String> picturesDir() async {
    return await _channel.invokeMethod("picturesDir");
  }

  Future<String> copyPictureToFolder(String folder, String path) async {
    return await _invoke(
      "copyPictureToFolder",
      {
        "folder": folder,
        "path": path,
      },
    );
  }

  Future<String> getProServerName() async {
    return await _invoke("get_pro_server_name", "");
  }

  Future setProServerName(String serverName) async {
    return await _invoke("set_pro_server_name", serverName);
  }

  Future<bool> verifyAuthentication() async {
    return await _channel.invokeMethod("verifyAuthentication");
  }

  Future<String> daily(int uid) {
    return _invoke("daily", uid);
  }

  Future<WeekData> week(int page) async {
    return WeekData.fromJson(jsonDecode(await _invoke("week", {
      "page": page,
    })));
  }

  Future<WeekFilterResponse> weekFilter(
      String categoryId, String typeId, int page) async {
    return WeekFilterResponse.fromJson(jsonDecode(await _invoke("week_filter", {
      "category_id": categoryId,
      "type_id": typeId,
      "page": page,
    })));
  }
}
