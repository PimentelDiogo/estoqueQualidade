import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pedido.dart';
import 'supabase_service.dart';

/// Fila de pedidos em tempo real.
///
/// **Esta interface é o ADR-002 na prática.** A Fase 2 usa Supabase Realtime,
/// mas nenhuma tela sabe disso: elas veem só um `Stream<List<Pedido>>`. Se um dia
/// o volume justificar Valkey Streams + WebSocket próprio, escreve-se outra
/// implementação e nada na UI muda.
abstract interface class OrderQueueService {
  /// Fila do ministério dono da mesa identificada por [qrToken].
  ///
  /// Emite a lista completa a cada mudança — a fila tem dezenas de itens, não
  /// milhares, então diferencial de eventos seria complexidade sem ganho.
  Stream<List<Pedido>> filaPorToken(String qrToken);

  /// Encerra a inscrição. Chamado no `onClose` da ViewModel.
  Future<void> encerrar();
}

class OrderQueueServiceSupabase implements OrderQueueService {
  OrderQueueServiceSupabase(this._supabase);

  final SupabaseService _supabase;

  RealtimeChannel? _canal;
  StreamController<List<Pedido>>? _controller;
  Timer? _reconciliador;

  @override
  Stream<List<Pedido>> filaPorToken(String qrToken) {
    _controller?.close();
    final StreamController<List<Pedido>> controller =
        StreamController<List<Pedido>>.broadcast();
    _controller = controller;

    unawaited(_iniciar(qrToken, controller));
    return controller.stream;
  }

  Future<void> _iniciar(
    String qrToken,
    StreamController<List<Pedido>> controller,
  ) async {
    await _buscar(qrToken, controller);

    await _canal?.unsubscribe();

    // Escutamos a TABELA e relemos a fila inteira pela RPC a cada evento.
    //
    // O payload do Postgres Changes traz só a linha de `pedido`, sem os itens e
    // sem o filtro por ministério do token. Reler garante que a TV mostre
    // exatamente o que a RPC autoriza — e o custo é irrelevante nesta escala.
    _canal = _supabase.client
        .channel('fila-tv-$qrToken')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedido',
          callback: (PostgresChangePayload _) {
            unawaited(_buscar(qrToken, controller));
          },
        )
        .subscribe();

    // Rede de celular derruba WebSocket sem avisar. Este heartbeat garante que
    // a TV do salão não fique congelada numa fila velha se a inscrição cair.
    _reconciliador?.cancel();
    _reconciliador = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_buscar(qrToken, controller)),
    );
  }

  Future<void> _buscar(
    String qrToken,
    StreamController<List<Pedido>> controller,
  ) async {
    if (controller.isClosed) return;

    try {
      final dynamic rows = await _supabase.client.rpc<dynamic>(
        'fn_fila_tv',
        params: <String, dynamic>{'p_qr_token': qrToken},
      );

      final List<Pedido> fila = (rows as List<dynamic>)
          .map((dynamic e) => Pedido.fromMap(e as Map<String, dynamic>))
          .toList();

      if (!controller.isClosed) controller.add(fila);
    } catch (e) {
      // Falha de rede não derruba a TV: ela segue exibindo a última fila
      // conhecida e o heartbeat tenta de novo em 45s. Fechar o stream aqui
      // deixaria o telão em branco no meio do culto.
      if (!controller.isClosed) controller.addError(e);
    }
  }

  @override
  Future<void> encerrar() async {
    _reconciliador?.cancel();
    _reconciliador = null;
    await _canal?.unsubscribe();
    _canal = null;
    await _controller?.close();
    _controller = null;
  }
}
