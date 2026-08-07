/// Resultado de uma operacao de Repository.
///
/// Motivo de existir: o voluntario precisa de **erro honesto na tela**, nao de um
/// stacktrace nem de um "algo deu errado" generico. O Repository traduz a excecao
/// tecnica (Postgres, rede, RLS) numa [AppFailure] com mensagem em portugues, e a
/// ViewModel so decide onde mostrar.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isFailure => this is Failure<T>;

  /// Valor, ou `null` se falhou.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final T value) => value,
    Failure<T>() => null,
  };

  /// Falha, ou `null` se deu certo.
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Failure<T>(:final AppFailure failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppFailure failure) onFailure,
  }) => switch (this) {
    Ok<T>(:final T value) => onOk(value),
    Failure<T>(:final AppFailure failure) => onFailure(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}

/// Categoria da falha — a UI reage diferente a cada uma.
enum FailureKind {
  /// Sem internet / servidor fora. Cabe "tentar de novo".
  rede,

  /// Login invalido ou sessao expirada. Manda pro login.
  autenticacao,

  /// RLS barrou. O usuario nao tem esse papel — nao adianta tentar de novo.
  permissao,

  /// Regra de negocio (ex.: estoque insuficiente). A mensagem ja e util.
  negocio,

  /// Dado invalido no formulario.
  validacao,

  /// Nao mapeada.
  desconhecida,
}

/// Falha com mensagem pronta para o voluntario ler.
class AppFailure implements Exception {
  const AppFailure({
    required this.mensagem,
    this.kind = FailureKind.desconhecida,
    this.detalheTecnico,
  });

  /// Texto exibido na tela, em portugues, sem jargao.
  final String mensagem;

  final FailureKind kind;

  /// Guardado so para log — **nunca** exibir ao usuario.
  final String? detalheTecnico;

  /// Se faz sentido oferecer o botao "Tentar de novo".
  bool get podeTentarDeNovo => kind == FailureKind.rede;

  const AppFailure.rede([String? detalhe])
    : mensagem = 'Sem conexao com o servidor. Verifique a internet.',
      kind = FailureKind.rede,
      detalheTecnico = detalhe;

  const AppFailure.autenticacao([String? detalhe])
    : mensagem = 'Sessao expirada. Entre novamente.',
      kind = FailureKind.autenticacao,
      detalheTecnico = detalhe;

  const AppFailure.permissao([String? detalhe])
    : mensagem = 'Voce nao tem permissao para esta acao.',
      kind = FailureKind.permissao,
      detalheTecnico = detalhe;

  const AppFailure.negocio(this.mensagem, [this.detalheTecnico])
    : kind = FailureKind.negocio;

  const AppFailure.validacao(this.mensagem, [this.detalheTecnico])
    : kind = FailureKind.validacao;

  @override
  String toString() =>
      'AppFailure($kind): $mensagem'
      '${detalheTecnico == null ? '' : ' | $detalheTecnico'}';
}
