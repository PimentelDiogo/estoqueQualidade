import 'dart:typed_data';

// Unico lugar da camada de dados que precisa nomear um tipo do SDK
// (FileOptions, no upload do QR). Views e ViewModels seguem proibidas de
// importar supabase_flutter — regras 1 e 2 do CLAUDE.md.
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/utils/result.dart';
import '../models/ministerio.dart';
import '../models/perfil_usuario.dart';
import '../services/supabase_service.dart';
import 'repositories.dart';

class MinisterioRepositorySupabase implements MinisterioRepository {
  MinisterioRepositorySupabase(this._supabase);

  static const String _bucketQrPix = 'pix-qr';

  final SupabaseService _supabase;

  @override
  Future<Result<List<Ministerio>>> listar({bool apenasAtivos = true}) =>
      _supabase.executar<List<Ministerio>>(() async {
        var query = _supabase.client.from('ministerio').select();
        if (apenasAtivos) query = query.eq('ativo', true);

        // A RLS ja filtra: admin ve todos, caixa ve so o proprio.
        final List<Map<String, dynamic>> rows = await query.order('nome');
        return rows.map(Ministerio.fromMap).toList();
      }, contexto: 'listarMinisterios');

  @override
  Future<Result<Ministerio>> porId(String id) =>
      _supabase.executar<Ministerio>(() async {
        final Map<String, dynamic> row = await _supabase.client
            .from('ministerio')
            .select()
            .eq('id', id)
            .single();
        return Ministerio.fromMap(row);
      }, contexto: 'ministerioPorId');

  @override
  Future<Result<Ministerio>> criar(Ministerio ministerio) =>
      _supabase.executar<Ministerio>(() async {
        final Map<String, dynamic> row = await _supabase.client
            .from('ministerio')
            .insert(ministerio.toInsert())
            .select()
            .single();
        return Ministerio.fromMap(row);
      }, contexto: 'criarMinisterio');

  @override
  Future<Result<Ministerio>> atualizar(Ministerio ministerio) =>
      _supabase.executar<Ministerio>(() async {
        final Map<String, dynamic> row = await _supabase.client
            .from('ministerio')
            .update(ministerio.toInsert())
            .eq('id', ministerio.id)
            .select()
            .single();
        return Ministerio.fromMap(row);
      }, contexto: 'atualizarMinisterio');

  @override
  Future<Result<String>> enviarImagemQrPix({
    required String ministerioId,
    required List<int> bytes,
    required String extensao,
  }) => _supabase.executar<String>(() async {
    final String caminho = '$ministerioId/qr-pix.$extensao';

    await _supabase.client.storage
        .from(_bucketQrPix)
        .uploadBinary(
          caminho,
          Uint8List.fromList(bytes),
          // upsert: trocar o QR e operacao normal (a chave Pix muda).
          fileOptions: const FileOptions(upsert: true),
        );

    // Cache-buster: sem isso, o navegador continuaria exibindo o QR antigo
    // depois da troca — e o dinheiro cairia na conta errada.
    final String url = _supabase.client.storage
        .from(_bucketQrPix)
        .getPublicUrl(caminho);

    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }, contexto: 'enviarImagemQrPix');

  @override
  Future<Result<List<Mesa>>> listarMesas(String ministerioId) =>
      _supabase.executar<List<Mesa>>(() async {
        final List<Map<String, dynamic>> rows = await _supabase.client
            .from('mesa')
            .select()
            .eq('ministerio_id', ministerioId)
            .eq('ativo', true)
            .order('identificador');
        return rows.map(Mesa.fromMap).toList();
      }, contexto: 'listarMesas');

  @override
  Future<Result<Mesa>> criarMesa({
    required String ministerioId,
    required String identificador,
  }) => _supabase.executar<Mesa>(() async {
    final Map<String, dynamic> row = await _supabase.client
        .from('mesa')
        // qr_token e gerado pelo banco (gen_random_bytes) — nao pelo cliente.
        .insert(<String, dynamic>{
          'ministerio_id': ministerioId,
          'identificador': identificador.trim(),
        })
        .select()
        .single();
    return Mesa.fromMap(row);
  }, contexto: 'criarMesa');
}

class UsuarioRepositorySupabase implements UsuarioRepository {
  UsuarioRepositorySupabase(this._supabase);

  final SupabaseService _supabase;

  @override
  Future<Result<List<PerfilUsuario>>> listar() =>
      _supabase.executar<List<PerfilUsuario>>(() async {
        // A RLS devolve so o proprio perfil para quem nao e admin.
        final List<Map<String, dynamic>> rows = await _supabase.client
            .from('perfil_usuario')
            .select(
              'id, nome, papel, ministerio_id, ativo, '
              'ministerio:ministerio_id ( nome )',
            )
            // Inativos primeiro: sao os que esperam liberacao do admin.
            .order('ativo')
            .order('nome');
        return rows.map(PerfilUsuario.fromMap).toList();
      }, contexto: 'listarUsuarios');

  @override
  Future<Result<PerfilUsuario>> atualizar(PerfilUsuario perfil) =>
      _supabase.executar<PerfilUsuario>(() async {
        final Map<String, dynamic> row = await _supabase.client
            .from('perfil_usuario')
            .update(<String, dynamic>{
              'nome': perfil.nome,
              'papel': perfil.papel.db,
              'ministerio_id': perfil.ministerioId,
              'ativo': perfil.ativo,
            })
            .eq('id', perfil.id)
            .select(
              'id, nome, papel, ministerio_id, ativo, '
              'ministerio:ministerio_id ( nome )',
            )
            .single();
        return PerfilUsuario.fromMap(row);
      }, contexto: 'atualizarUsuario');
}
