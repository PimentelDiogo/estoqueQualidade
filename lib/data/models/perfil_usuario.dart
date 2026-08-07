import 'enums.dart';

/// Perfil do usuario logado — quem e, que papel tem e de qual ministerio.
///
/// Espelha `public.perfil_usuario`. E a base do RBAC **na UI**; a autorizacao
/// de verdade e a RLS do Postgres (ADR-004). Confiar so nisto seria confiar num
/// objeto que vive no navegador do usuario.
class PerfilUsuario {
  const PerfilUsuario({
    required this.id,
    required this.nome,
    required this.papel,
    this.ministerioId,
    this.ministerioNome,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final PapelUsuario papel;

  /// Nulo para admin (enxerga todos os ministerios).
  final String? ministerioId;

  /// Vem do join — para exibir no cabecalho sem outra consulta.
  final String? ministerioNome;

  /// Nasce `false`: ninguem entra no sistema da igreja sem um admin liberar.
  final bool ativo;

  bool get isAdmin => papel == PapelUsuario.admin;
  bool get isCaixa => papel == PapelUsuario.caixa;

  /// Pode operar: liberado pelo admin e, se caixa, com ministerio vinculado.
  bool get podeOperar => ativo && (isAdmin || ministerioId != null);

  /// Pode cadastrar/editar ministerio e gerenciar usuarios.
  bool get podeGerenciarMinisterios => isAdmin;

  /// Pode ver relatorio de qualquer ministerio (caixa so ve o proprio).
  bool get podeVerTodosMinisterios => isAdmin;

  factory PerfilUsuario.fromMap(Map<String, dynamic> map) {
    final Object? ministerio = map['ministerio'];
    return PerfilUsuario(
      id: map['id'] as String,
      nome: map['nome'] as String,
      papel: PapelUsuario.fromDb(map['papel'] as String),
      ministerioId: map['ministerio_id'] as String?,
      ministerioNome: ministerio is Map<String, dynamic>
          ? ministerio['nome'] as String?
          : null,
      ativo: map['ativo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'nome': nome,
    'papel': papel.db,
    'ministerio_id': ministerioId,
    'ministerio_nome': ministerioNome,
    'ativo': ativo,
  };

  /// Reidrata do cache local (GetStorage) para nao piscar tela de login ao
  /// recarregar a aba. O perfil e reconferido no servidor logo em seguida.
  factory PerfilUsuario.fromCache(Map<String, dynamic> map) => PerfilUsuario(
    id: map['id'] as String,
    nome: map['nome'] as String,
    papel: PapelUsuario.fromDb(map['papel'] as String),
    ministerioId: map['ministerio_id'] as String?,
    ministerioNome: map['ministerio_nome'] as String?,
    ativo: map['ativo'] as bool? ?? false,
  );

  PerfilUsuario copyWith({
    String? nome,
    PapelUsuario? papel,
    String? ministerioId,
    String? ministerioNome,
    bool? ativo,
  }) => PerfilUsuario(
    id: id,
    nome: nome ?? this.nome,
    papel: papel ?? this.papel,
    ministerioId: ministerioId ?? this.ministerioId,
    ministerioNome: ministerioNome ?? this.ministerioNome,
    ativo: ativo ?? this.ativo,
  );
}
