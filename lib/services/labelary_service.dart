import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thermal_desk/models/label_profile.dart';

sealed class LabelaryResult<T> {
  const LabelaryResult();
}

final class LabelarySuccess<T> extends LabelaryResult<T> {
  final T value;
  const LabelarySuccess(this.value);
}

final class LabelaryFailure<T> extends LabelaryResult<T> {
  final String message;
  const LabelaryFailure(this.message);
}

class LabelaryService {
  final http.Client _client;
  final Duration timeout;

  LabelaryService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  /// Envia apenas por HTTPS. A UI exige ativação explícita do preview online.
  Future<LabelaryResult<List<int>>> renderZpl(
    String zpl, {
    required LabelProfile profile,
  }) async {
    if (zpl.trim().isEmpty) return const LabelaryFailure('ZPL vazio.');
    final url = Uri.https(
      'api.labelary.com',
      '/v1/printers/${profile.previewDpmm}dpmm/labels/'
          '${profile.widthInches.toStringAsFixed(6)}x'
          '${profile.heightInches.toStringAsFixed(6)}/0/',
    );
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=utf-8',
              'Accept': 'image/png',
            },
            body: utf8.encode(zpl),
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        const signature = [137, 80, 78, 71, 13, 10, 26, 10];
        final bytes = response.bodyBytes;
        if (bytes.length < signature.length ||
            !List.generate(
              signature.length,
              (i) => bytes[i] == signature[i],
            ).every((v) => v)) {
          return const LabelaryFailure(
            'O serviço devolveu uma imagem inválida.',
          );
        }
        return LabelarySuccess(bytes);
      }
      return LabelaryFailure(switch (response.statusCode) {
        400 => 'O serviço não conseguiu interpretar esta etiqueta.',
        429 => 'Limite de previews atingido. Aguarde e tente novamente.',
        _ => 'Serviço de preview indisponível (${response.statusCode}).',
      });
    } on TimeoutException {
      return const LabelaryFailure(
        'O preview online demorou demasiado. Tente novamente.',
      );
    } catch (_) {
      return const LabelaryFailure(
        'Sem ligação ao serviço de preview. A impressão local continua disponível.',
      );
    }
  }

  void close() => _client.close();
}
