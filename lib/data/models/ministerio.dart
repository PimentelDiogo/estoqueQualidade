/// Ministerio que serve no espaco (o Cafe e o primeiro; podem existir outros).
///
/// Cada um tem seu proprio PIX, produtos, caixa e relatorios — a chave de
/// isolamento de todo o sistema.
class Ministerio {
  const Ministerio({
    required this.id,
    required this.nome,
    required this.slug,
    this.responsavelNome,
    this.responsavelEmail,
    this.pixChave,
    this.pixPayloadQr,
    this.pixQrImageUrl,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final String slug;
  final String? responsavelNome;

  /// Destino do aviso de estoque baixo. Sem ele, o alerta so aparece no app.
  final String? responsavelEmail;

  final String? pixChave;

  /// Payload BR Code (copia-e-cola) — renderizado como QR no caixa.
  final String? pixPayloadQr;

  /// Alternativa para quem so tem a foto do QR (upload no Storage).
  final String? pixQrImageUrl;

  final bool ativo;

  /// Se da para cobrar por Pix: precisa do payload OU da imagem.
  bool get temPix =>
      (pixPayloadQr?.isNotEmpty ?? false) ||
      (pixQrImageUrl?.isNotEmpty ?? false);

  /// Se o aviso por e-mail vai sair. Falso => so alerta in-app.
  bool get recebeEmailDeAlerta => responsavelEmail?.isNotEmpty ?? false;

  factory Ministerio.fromMap(Map<String, dynamic> map) => Ministerio(
    id: map['id'] as String,
    nome: map['nome'] as String,
    slug: map['slug'] as String,
    responsavelNome: map['responsavel_nome'] as String?,
    responsavelEmail: map['responsavel_email'] as String?,
    pixChave: map['pix_chave'] as String?,
    pixPayloadQr: map['pix_payload_qr'] as String?,
    pixQrImageUrl: map['pix_qr_image_url'] as String?,
    ativo: map['ativo'] as bool? ?? true,
  );

  /// Sem `id`/`criado_em`: quem gera e o banco.
  Map<String, dynamic> toInsert() => <String, dynamic>{
    'nome': nome,
    'slug': slug,
    'responsavel_nome': responsavelNome,
    'responsavel_email': responsavelEmail,
    'pix_chave': pixChave,
    'pix_payload_qr': pixPayloadQr,
    'pix_qr_image_url': pixQrImageUrl,
    'ativo': ativo,
  };

  Ministerio copyWith({
    String? nome,
    String? slug,
    String? responsavelNome,
    String? responsavelEmail,
    String? pixChave,
    String? pixPayloadQr,
    String? pixQrImageUrl,
    bool? ativo,
  }) => Ministerio(
    id: id,
    nome: nome ?? this.nome,
    slug: slug ?? this.slug,
    responsavelNome: responsavelNome ?? this.responsavelNome,
    responsavelEmail: responsavelEmail ?? this.responsavelEmail,
    pixChave: pixChave ?? this.pixChave,
    pixPayloadQr: pixPayloadQr ?? this.pixPayloadQr,
    pixQrImageUrl: pixQrImageUrl ?? this.pixQrImageUrl,
    ativo: ativo ?? this.ativo,
  );

  /// `Espaco Cafe` -> `espaco-cafe` (a constraint do banco exige `^[a-z0-9-]+$`).
  static String gerarSlug(String nome) {
    const String comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const String semAcento = 'aaaaaeeeeiiiiooooouuuucn';

    String s = nome.toLowerCase().trim();
    for (int i = 0; i < comAcento.length; i++) {
      s = s.replaceAll(comAcento[i], semAcento[i]);
    }
    return s
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
