import '../../core/utils/result.dart';
import '../models/enums.dart';
import '../models/estoque.dart';
import '../models/produto.dart';
import '../services/supabase_service.dart';
import 'repositories.dart';

class ProdutoRepositorySupabase implements ProdutoRepository {
  ProdutoRepositorySupabase(this._supabase);

  final SupabaseService _supabase;

  @override
  Future<Result<List<Produto>>> listar({
    required String ministerioId,
    bool apenasAtivos = true,
  }) => _supabase.executar<List<Produto>>(() async {
    var query = _supabase.client
        .from('produto')
        .select()
        .eq('ministerio_id', ministerioId);

    if (apenasAtivos) query = query.eq('ativo', true);

    final List<Map<String, dynamic>> rows = await query.order('nome');
    return rows.map(Produto.fromMap).toList();
  }, contexto: 'listarProdutos');

  @override
  Future<Result<Produto?>> porCodigoBarras({
    required String ministerioId,
    required String codigo,
  }) => _supabase.executar<Produto?>(() async {
    final Map<String, dynamic>? row = await _supabase.client
        .from('produto')
        .select()
        .eq('ministerio_id', ministerioId)
        .eq('codigo_barras', codigo.trim())
        .eq('ativo', true)
        // maybeSingle: codigo desconhecido e situacao normal (produto sem
        // cadastro), nao erro. A tela oferece "cadastrar este codigo".
        .maybeSingle();

    return row == null ? null : Produto.fromMap(row);
  }, contexto: 'produtoPorCodigoBarras');

  @override
  Future<Result<Produto>> criar(Produto produto) =>
      _supabase.executar<Produto>(() async {
        final Map<String, dynamic> row = await _supabase.client
            .from('produto')
            .insert(<String, dynamic>{
              ...produto.toUpsert(),
              // Estoque inicial entra aqui; dai em diante so por movimentacao.
              'quantidade': produto.quantidade,
            })
            .select()
            .single();
        return Produto.fromMap(row);
      }, contexto: 'criarProduto');

  @override
  Future<Result<Produto>> atualizar(Produto produto) =>
      _supabase.executar<Produto>(() async {
        final Map<String, dynamic> row = await _supabase.client
            .from('produto')
            .update(produto.toUpsert())
            .eq('id', produto.id)
            .select()
            .single();
        return Produto.fromMap(row);
      }, contexto: 'atualizarProduto');

  @override
  Future<Result<void>> desativar(String produtoId) =>
      _supabase.executar<void>(() async {
        await _supabase.client
            .from('produto')
            .update(<String, dynamic>{'ativo': false})
            .eq('id', produtoId);
      }, contexto: 'desativarProduto');

  @override
  Future<Result<int>> movimentarEstoque({
    required String produtoId,
    required TipoMovimentacao tipo,
    required int quantidade,
    String? observacao,
  }) => _supabase.executar<int>(() async {
    final dynamic saldo = await _supabase.client.rpc<dynamic>(
      'fn_movimentar_estoque',
      params: <String, dynamic>{
        'p_produto_id': produtoId,
        'p_tipo': tipo.db,
        'p_quantidade': quantidade,
        'p_observacao': observacao,
      },
    );
    return (saldo as num).toInt();
  }, contexto: 'movimentarEstoque');

  @override
  Future<Result<List<MovimentacaoEstoque>>> historicoMovimentacoes({
    required String produtoId,
    int limite = 50,
  }) => _supabase.executar<List<MovimentacaoEstoque>>(() async {
    final List<Map<String, dynamic>> rows = await _supabase.client
        .from('movimentacao_estoque')
        .select('*, produto:produto_id ( nome ), usuario:usuario_id ( nome )')
        .eq('produto_id', produtoId)
        .order('criado_em', ascending: false)
        .limit(limite);

    return rows.map(MovimentacaoEstoque.fromMap).toList();
  }, contexto: 'historicoMovimentacoes');
}

class AlertaRepositorySupabase implements AlertaRepository {
  AlertaRepositorySupabase(this._supabase);

  final SupabaseService _supabase;

  @override
  Future<Result<List<AlertaEstoque>>> listar(String ministerioId) =>
      _supabase.executar<List<AlertaEstoque>>(() async {
        final List<Map<String, dynamic>> rows = await _supabase.client
            .from('vw_estoque_baixo')
            .select()
            .eq('ministerio_id', ministerioId)
            // Esgotados primeiro: sao os que travam a venda agora.
            .order('quantidade')
            .order('nome');

        return rows.map(AlertaEstoque.fromMap).toList();
      }, contexto: 'listarAlertas');

  @override
  Future<Result<void>> resolver(String alertaId) =>
      _supabase.executar<void>(() async {
        await _supabase.client
            .from('alerta_estoque')
            .update(<String, dynamic>{
              'status': 'resolvido',
              'resolvido_em': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', alertaId);
      }, contexto: 'resolverAlerta');
}
