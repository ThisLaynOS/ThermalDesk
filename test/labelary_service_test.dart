import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thermal_desk/models/label_profile.dart';
import 'package:thermal_desk/services/labelary_service.dart';

void main() {
  const profile = LabelProfile(360, 1200, 300);
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aHmsAAAAASUVORK5CYII=',
  );
  test(
    'HTTPS, UTF-8 e dimensões correspondem aos dots e DPI escolhidos',
    () async {
      final client = MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.path, contains('/12dpmm/labels/'));
        final size = request.url.path
            .split('/')[5]
            .split('x')
            .map(double.parse)
            .toList();
        expect(size[0] * profile.previewDpi, closeTo(360.01, .001));
        expect(size[1] * profile.previewDpi, closeTo(1200.01, .001));
        expect(utf8.decode(request.bodyBytes), '^XA^FDação & teste^FS^XZ');
        return http.Response.bytes(png, 200);
      });
      final service = LabelaryService(client: client);
      addTearDown(service.close);
      expect(
        await service.renderZpl('^XA^FDação & teste^FS^XZ', profile: profile),
        isA<LabelarySuccess<List<int>>>(),
      );
    },
  );
  test('Rejeita resposta inválida e não desce para HTTP em falhas', () async {
    var calls = 0;
    final service = LabelaryService(
      client: MockClient((request) async {
        calls++;
        return http.Response('not an image', 200);
      }),
    );
    addTearDown(service.close);
    expect(
      await service.renderZpl('^XA^XZ', profile: profile),
      isA<LabelaryFailure<List<int>>>(),
    );
    expect(calls, 1);
  });
  test('Timeout devolve erro recuperável', () async {
    final service = LabelaryService(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(service.close);
    expect(
      await service.renderZpl('^XA^XZ', profile: profile),
      isA<LabelaryFailure<List<int>>>(),
    );
  });
  test('Limite do serviço aparece como erro compreensível', () async {
    final service = LabelaryService(
      client: MockClient((_) async => http.Response('', 429)),
    );
    addTearDown(service.close);
    final result =
        await service.renderZpl('^XA^XZ', profile: profile) as LabelaryFailure;
    expect(result.message, contains('Limite'));
  });
}
