import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/utils/result.dart';

/// Unica porta de entrada para o Supabase no app inteiro.
///
/// Nenhuma View e nenhuma ViewModel importa `supabase_flutter` (regras 1 e 2 do
/// CLAUDE.md). Repositories usam este service; ele traduz as excecoes tecnicas do
/// Postgres em [AppFailure] com mensagem em portugues.
class SupabaseService extends GetxService {
  static SupabaseService get to => Get.find<SupabaseService>();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  /// Inicializa o SDK. Chamado uma vez no `main()`.
  static Future<void> inicializar() async {
    Env.validar();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // `anonKey` foi renomeado para `publishableKey` no SDK. O nome da variavel
      // de ambiente segue `SUPABASE_ANON_KEY` porque e assim que o dashboard
      // ainda rotula a chave.
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // O voluntario nao pode ser deslogado no meio do culto.
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        // A igreja usa a rede de dados do celular; reconecta sozinho.
        logLevel: RealtimeLogLevel.error,
      ),
    );
  }

  /// Envolve uma chamada ao Supabase e converte qualquer falha em [Result].
  ///
  /// Existe para que nenhum Repository precise repetir try/catch nem, pior,
  /// deixar vazar um stacktrace do Postgres para a tela do voluntario.
  Future<Result<T>> executar<T>(
    Future<T> Function() acao, {
    String? contexto,
  }) async {
    try {
      return Ok<T>(await acao());
    } on PostgrestException catch (e) {
      return Failure<T>(_traduzirPostgrest(e, contexto));
    } on AuthException catch (e) {
      return Failure<T>(
        AppFailure.autenticacao('${contexto ?? ''} ${e.message}'.trim()),
      );
    } on StorageException catch (e) {
      return Failure<T>(
        AppFailure(
          mensagem: 'Nao foi possivel salvar o arquivo.',
          detalheTecnico: '${contexto ?? ''} ${e.message}'.trim(),
        ),
      );
    } on TimeoutException catch (e) {
      return Failure<T>(AppFailure.rede('${contexto ?? ''} $e'.trim()));
    } catch (e) {
      // Falha de socket/DNS no Flutter Web nao tem tipo estavel; olhamos o texto.
      final String texto = e.toString().toLowerCase();
      final bool pareceRede =
          texto.contains('socket') ||
          texto.contains('failed to fetch') ||
          texto.contains('clientexception') ||
          texto.contains('connection');

      if (kDebugMode) {
        debugPrint('[SupabaseService] ${contexto ?? ''} $e');
      }

      return Failure<T>(
        pareceRede
            ? AppFailure.rede(e.toString())
            : AppFailure(
                mensagem: 'Algo deu errado. Tente novamente.',
                detalheTecnico: '${contexto ?? ''} $e'.trim(),
              ),
      );
    }
  }

  /// Traduz o erro do Postgres na frase que o voluntario precisa ler.
  ///
  /// As mensagens das RPCs vem em formato `chave: detalhe` (ver
  /// `fn_registrar_venda`), justamente para poderem ser reescritas aqui.
  AppFailure _traduzirPostgrest(PostgrestException e, String? contexto) {
    final String msg = e.message;
    final String detalhe = '${contexto ?? ''} [${e.code}] $msg'.trim();

    // --- Regras de negocio levantadas pelas RPCs -----------------------------
    if (msg.contains('estoque_insuficiente')) {
      // "estoque_insuficiente: Brownie (disponivel: 0, pedido: 2)"
      final String cauda = msg.split('estoque_insuficiente:').last.trim();
      return AppFailure.negocio('Estoque insuficiente: $cauda', detalhe);
    }
    if (msg.contains('produto_inativo')) {
      final String cauda = msg.split('produto_inativo:').last.trim();
      return AppFailure.negocio(
        'O produto "$cauda" esta inativo e nao pode ser vendido.',
        detalhe,
      );
    }
    if (msg.contains('venda_sem_itens')) {
      return AppFailure.negocio('Adicione ao menos um item a venda.', detalhe);
    }
    if (msg.contains('produto_nao_encontrado')) {
      return AppFailure.negocio('Produto nao encontrado.', detalhe);
    }
    if (msg.contains('quantidade_invalida')) {
      return AppFailure.validacao('Quantidade invalida.', detalhe);
    }
    if (msg.contains('desconto_invalido')) {
      return AppFailure.validacao('Desconto invalido.', detalhe);
    }
    if (msg.contains('use_fn_registrar_venda_para_vendas')) {
      return AppFailure.negocio(
        'Saida por venda deve ser feita pelo caixa.',
        detalhe,
      );
    }

    // --- Permissao / autenticacao -------------------------------------------
    if (msg.contains('sem_permissao_neste_ministerio') ||
        msg.contains('produto_de_outro_ministerio')) {
      return AppFailure.permissao(detalhe);
    }
    if (msg.contains('nao_autenticado') || e.code == '28000') {
      return AppFailure.autenticacao(detalhe);
    }

    // --- Codigos do Postgres -------------------------------------------------
    return switch (e.code) {
      // RLS barrou: a linha existe mas este papel nao alcanca.
      '42501' || 'PGRST301' => AppFailure.permissao(detalhe),
      '23505' => AppFailure.negocio(
        'Ja existe um registro com esses dados.',
        detalhe,
      ),
      '23503' => AppFailure.negocio(
        'Este registro esta sendo usado e nao pode ser removido.',
        detalhe,
      ),
      '23514' => AppFailure.validacao(
        'Dados invalidos para esta operacao.',
        detalhe,
      ),
      _ => AppFailure(
        mensagem: 'Algo deu errado. Tente novamente.',
        detalheTecnico: detalhe,
      ),
    };
  }
}
