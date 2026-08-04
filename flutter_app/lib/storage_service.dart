import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StorageService {
  StorageService({String? dbId}) : _dbId = dbId ?? defaultDbId;

  // Mantemos o mesmo identificador do plantel para preservar a cache local
  // já existente nos dispositivos e para que PC, tablet e telemóvel apontem
  // para o mesmo registo remoto.
  static const String defaultDbId = '019fb865-7007-7bb3-9f93-68f50bf7daa6';

  static const String supabaseUrl =
      'https://hzhplnxrnqiejfrnmksr.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_n2VlIKJp5I7DBo8PE9SYQA_xjwn2izV';
  static const String tableName = 'plantel_state';

  String _dbId;

  String get dbId => _dbId;
  String get remoteUrl => '$supabaseUrl/rest/v1/$tableName';
  String get localKey => 'f7_flutter_$_dbId';

  Map<String, String> get _readHeaders => const {
        'Accept': 'application/json',
        'apikey': supabasePublishableKey,
      };

  Map<String, String> get _writeHeaders => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'apikey': supabasePublishableKey,
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      };

  Future<void> setDbId(String value) async {
    final parsed = extractDbId(value);
    if (parsed.isEmpty) return;
    _dbId = parsed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('f7_flutter_current_db', parsed);
  }

  int _updatedAtFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return -1;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return -1;
      return (decoded['updatedAt'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return -1;
    }
  }

  Future<void> loadSavedDbId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString('f7_flutter_current_db') ?? '').trim();

    // A partir do backend Supabase existe um plantel principal comum aos
    // dispositivos. Se uma instalação tinha ficado num ID antigo diferente,
    // preservamos a cache mais recente antes de regressar ao ID canónico.
    if (saved.isNotEmpty && saved != defaultDbId) {
      final oldRaw = prefs.getString('f7_flutter_$saved');
      final canonicalKey = 'f7_flutter_$defaultDbId';
      final canonicalRaw = prefs.getString(canonicalKey);
      if (_updatedAtFromRaw(oldRaw) > _updatedAtFromRaw(canonicalRaw) &&
          oldRaw != null &&
          oldRaw.isNotEmpty) {
        await prefs.setString(canonicalKey, oldRaw);
      }
    }

    _dbId = defaultDbId;
    await prefs.setString('f7_flutter_current_db', defaultDbId);
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
    final uri = Uri.parse(remoteUrl).replace(queryParameters: {
      'plantel_id': 'eq.$_dbId',
      'select': 'payload,updated_at_ms',
      'limit': '1',
    });

    final response = await http.get(uri, headers: _readHeaders);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Falha ao carregar online: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) {
      return PlantelStateData.empty();
    }

    final row = Map<String, dynamic>.from(decoded.first as Map);
    final payloadRaw = row['payload'];
    if (payloadRaw is! Map) return PlantelStateData.empty();

    final data = PlantelStateData.fromJson(
      Map<String, dynamic>.from(payloadRaw),
    );
    final remoteUpdatedAt = (row['updated_at_ms'] as num?)?.toInt() ?? 0;
    if (remoteUpdatedAt > data.updatedAt) data.updatedAt = remoteUpdatedAt;
    return data;
  }

  Future<void> saveRemote(PlantelStateData data) async {
    final uri = Uri.parse(remoteUrl).replace(queryParameters: {
      'on_conflict': 'plantel_id',
    });

    final response = await http.post(
      uri,
      headers: _writeHeaders,
      body: jsonEncode({
        'plantel_id': _dbId,
        'payload': data.toJson(),
        'updated_at_ms': data.updatedAt,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Falha ao guardar online: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<String> createRemote(PlantelStateData data) async {
    final id = uid();
    await setDbId(id);
    await saveRemote(data);
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
