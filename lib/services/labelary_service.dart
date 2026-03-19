import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

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
  static const String _baseUrlHttp =
      'http://api.labelary.com/v1/printers/8dpmm/labels/4x6/0/';
  static const String _baseUrlHttps =
      'https://api.labelary.com/v1/printers/8dpmm/labels/4x6/0/';

  /// Renderiza ZPL para imagem PNG via Labelary API
  /// Retorna bytes da imagem se sucesso, erro caso contrário
  Future<LabelaryResult<List<int>>> renderZpl(String zpl) async {
    try {
      // Validar ZPL não vazio
      if (zpl.trim().isEmpty) {
        developer.log('Labelary: ZPL vazio');
        return const LabelaryFailure('ZPL vazio');
      }

      developer.log('Labelary: iniciando renderização com ${zpl.length} chars');

      // Tentar HTTPS primeiro, depois HTTP
      var response = await _tryPost(_baseUrlHttps, zpl);
      
      // Se HTTPS falhar com erro de conexão, tentar HTTP
      if (response == null) {
        developer.log('Labelary: tentando HTTP depois de falha em HTTPS');
        response = await _tryPost(_baseUrlHttp, zpl);
      }

      // Se ambos falharem, retornar erro
      if (response == null) {
        developer.log('Labelary: nenhuma URL funcionou');
        return const LabelaryFailure('Não foi possível conectar ao Labelary API');
      }

      developer.log('Labelary: resposta ${response.statusCode}, '
          '${response.bodyBytes.length} bytes');

      // Sucesso: status 200 com imagem em bytes
      if (response.statusCode == 200) {
        developer.log('Labelary: sucesso!');
        return LabelarySuccess(response.bodyBytes);
      }

      // Falha: erro da API (400, 500, etc.)
      final errorMsg = response.statusCode == 400
          ? 'ZPL inválido (erro 400)'
          : 'Erro ${response.statusCode} do Labelary API';
      developer.log('Labelary: $errorMsg');
      return LabelaryFailure(errorMsg);
    } on TimeoutException catch (e) {
      developer.log('Labelary: timeout - ${e.message}');
      return LabelaryFailure('Timeout ao renderizar: ${e.message}');
    } catch (e) {
      developer.log('Labelary: erro - $e');
      return LabelaryFailure('Erro ao conectar Labelary: $e');
    }
  }

  /// Tenta fazer POST para uma URL específica
  /// Retorna a response se bem sucedido, null se timeout/erro de conexão
  Future<http.Response?> _tryPost(String url, String zpl) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'image/png',
            },
            body: zpl,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Timeout em $url'),
          );
      return response;
    } catch (e) {
      developer.log('Labelary: falha em $url - $e');
      return null;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
