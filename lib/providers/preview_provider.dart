import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/services/labelary_service.dart';

final labelaryServiceProvider = Provider<LabelaryService>((ref) {
  final service = LabelaryService();
  ref.onDispose(service.close);
  return service;
});
