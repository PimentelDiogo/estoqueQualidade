import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../models/enums.dart';
import '../models/venda.dart';
import '../services/supabase_service.dart';
import 'repositories.dart';

class VendaRepositorySupabase implements VendaRepository {
  VendaRepositorySupabase(this._supabase);

  final SupabaseService _supabase;

  @override
  Future<Result<String>> registrar({
    required String ministerioId,
    required TipoVenda tipo,
    required List<ItemCarrinho> itens,
    double desconto = 0,
    String? observacao,
  }) => _supabase.executar<String>(() async {
    // UMA chamada, UMA transacao (ADR-003). Nao existe caminho alternativo:
    // a tabela `venda` nao tem policy de INSERT.
    final dynamic id = await _supabase.client.rpc<dynamic>(
      'fn_registrar_venda',
      params: <String, dynamic>{
        'p_ministerio_id': ministerioId,
        'p_tipo': tipo.db,
        'p_itens': itens
            .map((ItemCarrinho i) => i.toRpcItem())
            .toList(growable: false),
        'p_desconto': desconto,
        'p_observacao': observacao,
      },
    );
    return id as String;
  }, contexto: 'registrarVenda');

  @override
  Future<Result<Venda>> porId(String vendaId) =>
      _supabase.executar<Venda>(() async {
        final Map<String, dynamic> row = await _supabase.client
            .from('venda')
            .select('*, venda_item(*)')
            .eq('id', vendaId)
            .single();
        return Venda.fromMap(row);
      }, contexto: 'vendaPorId');

  @override
  Future<Result<List<Venda>>> listar({
    required String ministerioId,
    required DateRange periodo,
    int limite = 100,
  }) => _supabase.executar<List<Venda>>(() async {
    final List<Map<String, dynamic>> rows = await _supabase.client
        .from('venda')
        .select('*, venda_item(*)')
        .eq('ministerio_id', ministerioId)
        .gte('criado_em', periodo.inicioIso)
        .lt('criado_em', periodo.fimIso)
        .order('criado_em', ascending: false)
        .limit(limite);

    return rows.map(Venda.fromMap).toList();
  }, contexto: 'listarVendas');
}

class RelatorioRepositorySupabase implements RelatorioRepository {
  RelatorioRepositorySupabase(this._supabase);

  final SupabaseService _supabase;

  @override
  Future<Result<ResumoPeriodo>> resumo({
    required String ministerioId,
    required DateRange periodo,
  }) => _supabase.executar<ResumoPeriodo>(() async {
    final dynamic rows = await _supabase.client.rpc<dynamic>(
      'fn_resumo_periodo',
      params: <String, dynamic>{
        'p_ministerio_id': ministerioId,
        'p_inicio': periodo.inicioIso,
        'p_fim': periodo.fimIso,
      },
    );

    // A funcao retorna TABLE: vem uma lista de uma linha so.
    final List<dynamic> lista = rows as List<dynamic>;
    if (lista.isEmpty) return const ResumoPeriodo();
    return ResumoPeriodo.fromMap(lista.first as Map<String, dynamic>);
  }, contexto: 'resumoPeriodo');

  @override
  Future<Result<List<VendaAgregada>>> serie({
    required String ministerioId,
    required Periodo granularidade,
    required DateRange periodo,
  }) => _supabase.executar<List<VendaAgregada>>(() async {
    final dynamic rows = await _supabase.client.rpc<dynamic>(
      'fn_vendas_periodo',
      params: <String, dynamic>{
        'p_ministerio_id': ministerioId,
        'p_granularidade': granularidade.granularidade,
        'p_inicio': periodo.inicioIso,
        'p_fim': periodo.fimIso,
      },
    );

    return (rows as List<dynamic>)
        .map((dynamic e) => VendaAgregada.fromMap(e as Map<String, dynamic>))
        .toList();
  }, contexto: 'seriePeriodo');

  @override
  Future<Result<List<ProdutoMaisVendido>>> maisVendidos({
    required String ministerioId,
    required DateRange periodo,
    int limite = 10,
  }) => _supabase.executar<List<ProdutoMaisVendido>>(() async {
    final dynamic rows = await _supabase.client.rpc<dynamic>(
      'fn_produtos_mais_vendidos',
      params: <String, dynamic>{
        'p_ministerio_id': ministerioId,
        'p_inicio': periodo.inicioIso,
        'p_fim': periodo.fimIso,
        'p_limite': limite,
      },
    );

    return (rows as List<dynamic>)
        .map(
          (dynamic e) => ProdutoMaisVendido.fromMap(e as Map<String, dynamic>),
        )
        .toList();
  }, contexto: 'produtosMaisVendidos');
}
