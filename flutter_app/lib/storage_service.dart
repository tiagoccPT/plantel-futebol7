import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StorageService {
  StorageService({String? dbId}) : _dbId = dbId ?? defaultDbId;

  static const String defaultDbId = '019fb865-7007-7bb3-9f93-68f50bf7daa6';
  static const String jsonBlobApi = 'https://jsonblob.com/api/jsonBlob';
  static const String webBase =
      'https://raw.githack.com/tiagoccPT/plantel-futebol7/main/plantel-online.html';

  String _dbId;

  String get dbId => _dbId;
  String get remoteUrl => '$jsonBlobApi/${Uri.encodeComponent(_dbId)}';
  String get webShareUrl => '$webBase#db=$_dbId';
  String get localKey => 'f7_flutter_$_dbId';

  Future<void> setDbId(String value) async {
    final parsed = extractDbId(value);
    if (parsed.isEmpty) return;
    _dbId = parsed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('f7_flutter_current_db', parsed);
  }

  Future<void> loadSavedDbId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('f7_flutter_current_db');
    if (saved != null && saved.trim().isNotEmpty) _dbId = saved.trim();
  }

  String extractDbId(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) return value;
    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    final params = Uri.splitQueryString(uri.fragment);
    return params['db'] ?? '';
  }

  Future<PlantelStateData> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(localKey);
    if (raw == null || raw.isEmpty) return PlantelStateData.empty();
    try {
      return PlantelStateData.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return PlantelStateData.empty();
    }
  }

  Future<void> saveLocal(PlantelStateData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localKey, jsonEncode(data.toJson()));
  }

  Future<PlantelStateData> loadRemote() async {
    final response = await http.get(
      Uri.parse(remoteUrl),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao carregar online: ${response.statusCode}');
    }
    return PlantelStateData.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<void> saveRemote(PlantelStateData data) async {
    final response = await http.put(
      Uri.parse(remoteUrl),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(data.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao guardar online: ${response.statusCode}');
    }
  }

  Future<String> createRemote(PlantelStateData data) async {
    final response = await http.post(
      Uri.parse(jsonBlobApi),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(data.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao criar armazenamento online.');
    }

    final header = response.headers['x-jsonblob'] ?? response.headers['location'];
    if (header == null || header.isEmpty) {
      throw Exception('O serviço não devolveu o identificador do plantel.');
    }
    final id = header.split('/').where((e) => e.isNotEmpty).last;
    await setDbId(id);
    return id;
  }

  Future<PlantelStateData> importBackup(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Backup inválido.');
    final data = PlantelStateData.fromJson(Map<String, dynamic>.from(decoded));
    await saveLocal(data);
    return data;
  }
}
