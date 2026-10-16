import 'dart:convert';

import 'package:flutter/material.dart';

enum LabelTemplate {
  basic,
  product,
  address,
  shipping,
  inventory,
  priceTag,
  qrCode,
  cable,
  promoShelf,
  promoExpiry,
  custom;

  // Mantém os índices antigos para ler o histórico, sem oferecer estes modelos.
  static const standard = [basic, address, shipping, inventory, qrCode, cable];
}

extension LabelTemplateLabel on LabelTemplate {
  String get displayName => switch (this) {
    LabelTemplate.custom => 'Personalizado',
    LabelTemplate.basic => 'Básico',
    LabelTemplate.product => 'Produto',
    LabelTemplate.address => 'Endereço',
    LabelTemplate.shipping => 'Expedição',
    LabelTemplate.inventory => 'Inventário',
    LabelTemplate.priceTag => 'Preço',
    LabelTemplate.qrCode => 'QR Code',
    LabelTemplate.cable => 'Cabo/Fio',
    LabelTemplate.promoShelf => 'Oferta Gôndola',
    LabelTemplate.promoExpiry => 'Oferta Vencimento',
  };

  String get description => switch (this) {
    LabelTemplate.custom => 'Etiqueta criada no designer',
    LabelTemplate.basic => 'Título e código de barras simples',
    LabelTemplate.product => 'Nome, descrição e código do produto',
    LabelTemplate.address => 'Etiqueta de endereço/remetente',
    LabelTemplate.shipping => 'Etiqueta de envio com rastreio',
    LabelTemplate.inventory => 'Controle de estoque com localização',
    LabelTemplate.priceTag => 'Etiqueta de preço para gôndola',
    LabelTemplate.qrCode => 'QR Code com informações',
    LabelTemplate.cable => 'Identificação de cabos/fios',
    LabelTemplate.promoShelf =>
      'Produto, preço anterior/novo e quantidade de impressão',
    LabelTemplate.promoExpiry =>
      'Oferta com vencimento (mês/ano), preços e quantidade',
  };

  IconData get icon => switch (this) {
    LabelTemplate.custom => Icons.design_services_outlined,
    LabelTemplate.basic => Icons.label,
    LabelTemplate.product => Icons.inventory_2_outlined,
    LabelTemplate.address => Icons.location_on_outlined,
    LabelTemplate.shipping => Icons.local_shipping_outlined,
    LabelTemplate.inventory => Icons.warehouse_outlined,
    LabelTemplate.priceTag => Icons.sell_outlined,
    LabelTemplate.qrCode => Icons.qr_code_2,
    LabelTemplate.cable => Icons.cable_outlined,
    LabelTemplate.promoShelf => Icons.local_offer_outlined,
    LabelTemplate.promoExpiry => Icons.event_outlined,
  };
}

class LabelJob {
  final String id;
  final DateTime sentAt;
  final String title;
  final String barcode;
  final String subtitle;
  final LabelTemplate template;
  final bool success;
  final String zpl;

  const LabelJob({
    required this.id,
    required this.sentAt,
    required this.title,
    required this.barcode,
    required this.subtitle,
    required this.template,
    required this.success,
    required this.zpl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sentAt': sentAt.toIso8601String(),
    'title': title,
    'barcode': barcode,
    'subtitle': subtitle,
    'template': template.index,
    'success': success,
    'zpl': zpl,
  };

  factory LabelJob.fromJson(Map<String, dynamic> j) => LabelJob(
    id: j['id'] as String,
    sentAt: DateTime.parse(j['sentAt'] as String),
    title: j['title'] as String? ?? '',
    barcode: j['barcode'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    template:
        LabelTemplate.values.elementAtOrNull(j['template'] as int? ?? 0) ??
        LabelTemplate.basic,
    success: j['success'] as bool? ?? true,
    zpl: j['zpl'] as String? ?? '',
  );

  String toJsonString() => jsonEncode(toJson());
  factory LabelJob.fromJsonString(String s) =>
      LabelJob.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
