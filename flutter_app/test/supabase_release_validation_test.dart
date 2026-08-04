import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Supabase release 1.0.7 permite leitura e escrita', () async {
    const base = 'https://hzhplnxrnqiejfrnmksr.supabase.co/rest/v1/plantel_state';
    const key = 'sb_publishable_n2VlIKJp5I7DBo8PE9SYQA_xjwn2izV';
    const id = '019fb865-7007-7bb3-9f93-68f50bf7daa6';

    final getResponse = await http.get(
      Uri.parse(base).replace(queryParameters: const {
        'plantel_id': 'eq.$id',
        'select': 'plantel_id,payload,updated_at_ms',
        'limit': '1',
      }),
      headers: const {'apikey': key, 'Accept': 'application/json'},
    );
    expect(getResponse.statusCode, 200, reason: getResponse.body);
    final rows = jsonDecode(getResponse.body) as List<dynamic>;
    expect(rows, hasLength(1), reason: getResponse.body);
    final row = Map<String, dynamic>.from(rows.single as Map);

    final postResponse = await http.post(
      Uri.parse(base).replace(queryParameters: const {'on_conflict': 'plantel_id'}),
      headers: const {
        'apikey': key,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: jsonEncode({
        'plantel_id': row['plantel_id'],
        'payload': row['payload'],
        'updated_at_ms': row['updated_at_ms'],
      }),
    );
    expect(postResponse.statusCode, anyOf(200, 201, 204), reason: postResponse.body);
  });
}
