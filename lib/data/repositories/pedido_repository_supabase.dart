import '../../core/utils/result.dart';
import '../models/enums.dart';
import '../models/pedido.dart';
import '../services/supabase_service.dart';
import 'repositories.dart';

class PedidoRepositorySupabase implements PedidoRepository {
  PedidoRepositorySupabase(this._supabase);

  final SupabaseService _supabase;

  @override
  Future<Result<List<ItemCardapio>>> cardapio(String qrToken) =>
      _supabase.executar<List<ItemCardapio>>(() async {
        // Primeiro descobre o ministério da mesa (a view não conhece o token).
        final Map<String, dynamic> mesa = await _supabase.client
            .from('mesa')
            .select('ministerio_id, identificador')
            .eq('qr_token', qrToken)
            .eq('ativo', true)
            .single();

        final List<Map<String, dynamic>> rows = await _supabase.client
            .from('vw_cardapio')
            .select()
            .eq('ministerio_id', mesa['ministerio_id'] as String)
            .order('nome');

        return rows.map(ItemCardapio.fromMap).toList();
      }, contexto: 'cardapio');

  @override
  Future<Result<PedidoCriado>> criar({
    required String qrToken,
    required List<ItemPedidoCliente> itens,
    String? clienteNome,
    String? observacao,
  }) => _supabase.executar<PedidoCriado>(() async {
    final dynamic rows = await _supabase.client.rpc<dynamic>(
      'fn_criar_pedido',
      params: <String, dynamic>{
        'p_qr_token': qrToken,
        'p_itens': itens
            .map((ItemPedidoCliente i) => i.toRpcItem())
            .toList(growable: false),
        'p_cliente_nome': clienteNome,
        'p_observacao': observacao,
      },
    );

    final Map<String, dynamic> row =
        (rows as List<dynamic>).first as Map<String, dynamic>;

    return PedidoCriado(
      id: row['pedido_id'] as String,
      senha: row['senha'] as String,
    );
  }, contexto: 'criarPedido');

  @override
  Future<Result<StatusPedido>> statusDoPedido(String pedidoId) =>
      _supabase.executar<StatusPedido>(() async {
        final dynamic rows = await _supabase.client.rpc<dynamic>(
          'fn_status_pedido',
          params: <String, dynamic>{'p_pedido_id': pedidoId},
        );

        final List<dynamic> lista = rows as List<dynamic>;
        if (lista.isEmpty) {
          throw StateError('pedido_nao_encontrado');
        }
        return StatusPedido.fromDb(
          (lista.first as Map<String, dynamic>)['status'] as String,
        );
      }, contexto: 'statusPedido');

  @override
  Future<Result<List<Pedido>>> filaDoMinisterio(String ministerioId) =>
      _supabase.executar<List<Pedido>>(() async {
        final List<Map<String, dynamic>> rows = await _supabase.client
            .from('pedido')
            .select('*, pedido_item(*), mesa:mesa_id ( identificador )')
            .eq('ministerio_id', ministerioId)
            .inFilter('status', <String>['recebido', 'preparando', 'pronto'])
            .order('criado_em');

        return rows.map(Pedido.fromMap).toList();
      }, contexto: 'filaMinisterio');

  @override
  Future<Result<void>> mudarStatus({
    required String pedidoId,
    required StatusPedido status,
  }) => _supabase.executar<void>(() async {
    await _supabase.client
        .from('pedido')
        .update(<String, dynamic>{'status': status.db})
        .eq('id', pedidoId);
  }, contexto: 'mudarStatusPedido');

  @override
  Future<Result<String>> converterEmVenda({
    required String pedidoId,
    required TipoVenda tipo,
    double desconto = 0,
  }) => _supabase.executar<String>(() async {
    // Reaproveita fn_registrar_venda por dentro: ganha a transação, o
    // FOR UPDATE e a validação de estoque do ADR-003 sem duplicar nada.
    final dynamic id = await _supabase.client.rpc<dynamic>(
      'fn_converter_pedido_em_venda',
      params: <String, dynamic>{
        'p_pedido_id': pedidoId,
        'p_tipo': tipo.db,
        'p_desconto': desconto,
      },
    );
    return id as String;
  }, contexto: 'converterPedidoEmVenda');
}
