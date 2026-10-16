import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/models/custom_label.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/providers/custom_labels_provider.dart';

CustomLabel exampleLabel() => CustomLabel(
  id: 'example',
  name: 'Minha etiqueta',
  widthMm: 60,
  heightMm: 40,
  elements: const [
    LabelElement(
      id: 'title',
      type: LabelElementType.text,
      content: 'Produto Exemplo',
      fieldName: 'Produto',
      editable: true,
    ),
    LabelElement(
      id: 'price',
      type: LabelElementType.text,
      y: 9,
      content: r'R$ 0,00',
      fieldName: 'Preço',
      editable: true,
    ),
    LabelElement(
      id: 'barcode',
      type: LabelElementType.barcode,
      y: 16,
      width: 45,
      height: 12,
      content: '0000000000000',
      fieldName: 'Código',
      editable: true,
    ),
    LabelElement(
      id: 'qr',
      type: LabelElementType.qr,
      x: 43,
      y: 2,
      width: 15,
      height: 15,
      content: 'https://exemplo.local',
    ),
    LabelElement(
      id: 'border',
      type: LabelElementType.box,
      x: 1,
      y: 1,
      width: 58,
      height: 38,
    ),
    LabelElement(
      id: 'line',
      type: LabelElementType.line,
      y: 30,
      width: 45,
      height: .4,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Modelo portável preserva layout e não inclui destino de impressão', () {
    final label = exampleLabel();
    final imported = CustomLabel.decode(label.encode(), newIdentity: true);
    expect(imported.id, isNot(label.id));
    expect(imported.copyWith(id: label.id).toJson(), label.toJson());
    expect(imported.toJson().keys, isNot(contains('ip')));
    expect(imported.toJson().keys, isNot(contains('port')));
    for (final dpi in [200, 203, 300]) {
      expect(imported.buildZpl(dpi), label.buildZpl(dpi));
      expect(imported.issues(dpi), isEmpty);
      expect(
        imported.buildZpl(dpi),
        contains('^PW${(60 * dpi / 25.4).round()}'),
      );
    }
  });

  test('Dados Unicode e comandos viram somente dados hexadecimais', () {
    final label = exampleLabel();
    final zpl = label.buildZpl(203, values: {'title': 'Ação ^XZ~JA_ & teste'});
    expect(RegExp(r'\^XA').allMatches(zpl).length, 1);
    expect(RegExp(r'\^XZ').allMatches(zpl).length, 1);
    expect(zpl, isNot(contains('~JA')));
    expect(zpl, contains('_41_C3_A7_C3_A3_6F'));
    expect(zpl, contains('^CI28'));
    expect(zpl, contains('^FH_'));
    expect(zpl, contains('^FB'));
    expect(zpl, contains('^BCN'));
    expect(label.elements.first.content, 'Produto Exemplo');
  });

  test('Importação recusa versão, tipos, dimensões e IDs inválidos', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (j) => j['version'] = 99,
      (j) => j['format'] = 'other',
      (j) => j['widthMm'] = -1,
      (j) => j['heightMm'] = '40',
      (j) => j['name'] = '',
      (j) => j['elements'][0]['type'] = 'rawZpl',
      (j) => j['elements'][0]['x'] = 100,
      (j) => j['elements'][0]['content'] = 'x\u0000y',
      (j) => j['elements'][1]['id'] = 'title',
      (j) => j['elements'] = List.generate(51, (_) => j['elements'][0]),
    ]) {
      final json = exampleLabel().toJson();
      mutate(json);
      expect(() => CustomLabel.decode(jsonEncode(json)), throwsFormatException);
    }
    expect(() => CustomLabel.decode('not json'), throwsFormatException);
    expect(() => CustomLabel.decode('[]'), throwsFormatException);
    expect(
      () => CustomLabel.decode('x' * (CustomLabel.maxBytes + 1)),
      throwsFormatException,
    );
  });

  test(
    'Rejeita códigos incompatíveis, campos vazios e elementos fora do papel',
    () {
      final label = exampleLabel();
      for (final content in ['', '^XZ', '>ABC', 'A' * 81]) {
        expect(
          () => label.buildZpl(203, values: {'barcode': content}),
          throwsFormatException,
        );
      }
      expect(
        () => label.buildZpl(203, values: {'title': ''}),
        throwsFormatException,
      );
      expect(
        () => label.copyWith(widthMm: 20).buildZpl(203),
        throwsFormatException,
      );
      expect(() => label.buildZpl(203, copies: 0), throwsFormatException);
      expect(() => label.buildZpl(203, copies: 1001), throwsFormatException);
      expect(label.buildZpl(203, copies: 3), contains('^PQ3'));
      final qr = label.elements.firstWhere(
        (e) => e.type == LabelElementType.qr,
      );
      expect(
        () => label
            .copyWith(elements: [qr.copyWith(width: .2, height: .2)])
            .buildZpl(203),
        throwsFormatException,
      );
    },
  );

  test('Campo fixo não recebe valor substituído e campo editável recebe', () {
    final label = exampleLabel();
    expect(label.valueOf(label.elements.last, {'line': 'injected'}), '');
    expect(
      label.valueOf(label.elements.first, {'title': 'Item Genérico'}),
      'Item Genérico',
    );
    expect(label.elements.first.content, 'Produto Exemplo');
  });

  test(
    'Catálogo padrão remove modelos pedidos sem alterar índices do histórico',
    () {
      expect(LabelTemplate.standard, isNot(contains(LabelTemplate.priceTag)));
      expect(LabelTemplate.standard, isNot(contains(LabelTemplate.custom)));
      expect(LabelTemplate.address.storageId, 2);
      expect(LabelTemplate.custom.storageId, 10);
      expect(LabelTemplate.fromStorage(1), LabelTemplate.basic);
      expect(LabelTemplate.fromStorage(8), LabelTemplate.basic);
      expect(LabelTemplate.fromStorage(9), LabelTemplate.basic);
    },
  );

  test('Salvar durante carregamento, editar, reabrir e excluir preservam os modelos', () async {
    SharedPreferences.setMockInitialValues({
      CustomLabelsNotifier.storageKey: [exampleLabel().encode(), 'corrupt'],
    });
    final notifier = CustomLabelsNotifier();
    addTearDown(notifier.dispose);
    final copy = exampleLabel().copyWith(
      id: 'second',
      name: 'Segunda etiqueta',
    );
    await notifier.save(copy);
    expect(notifier.skippedRecords, 1);
    expect(notifier.state.requireValue.length, 2);
    await Future.wait([
      notifier.save(copy.copyWith(name: 'Atualizada')),
      notifier.remove('example'),
    ]);
    final restarted = CustomLabelsNotifier();
    addTearDown(restarted.dispose);
    await restarted.ready;
    expect(restarted.state.requireValue.single.name, 'Atualizada');
    expect(restarted.state.requireValue.single.id, 'second');
  });
}
