---
tags: [adr, espaco-cafe, flutter, web, wasm, persistencia]
criado: 2026-08-07
status: aceito
decisao: "Usar shared_preferences no lugar de get_storage para não bloquear o build WebAssembly"
---

# ADR-006 — `shared_preferences` em vez de `get_storage` (build wasm)

> **Status:** aceito · **Data:** 2026-08-07 · **Decisor:** Diogo
> **Relaciona:** [[ADR-001-mvvm-getx]]

## Contexto

O app precisa guardar **uma** coisa localmente: qual ministério o admin escolheu por último, para
ele não ter que reescolher a cada recarga da aba. Sessão e token são responsabilidade do SDK do
Supabase, não nossa.

A escolha natural era `get_storage` — é do mesmo autor do GetX e tem API síncrona, que combina
com a leitura direta no `SessionService`.

O problema apareceu no build:

```
$ fvm flutter build web --release
Wasm dry run findings:
package:get_storage/src/storage/html.dart 4:1 - dart:html unsupported (0)
```

`get_storage` usa `dart:html`, que **não existe** na compilação para WebAssembly. O build JS
funciona normalmente; o wasm é bloqueado por essa única dependência transitiva.

Wasm importa aqui pelo caso de uso mais pesado do sistema: a **TV** com fila em tempo real e
tipografia ampliada (Fase 2), e o **tablet** do caixa. São os contextos onde o ganho de
performance de renderização é perceptível.

## Decisão

Trocar por **`shared_preferences`**, isolado num `PreferenciasService`.

Dois fatos ajudaram: o pacote **já estava na árvore de dependências** (transitivo do
`supabase_flutter`), então a troca *removeu* uma dependência direta em vez de adicionar; e o
consumidor é um só.

### O custo: API assíncrona

`SharedPreferences.getInstance()` é `Future`, mas o `SessionService` lê o valor de forma síncrona
dentro de `_sincronizarComPerfil`. A solução é resolver a instância **uma vez no boot** e injetá-la:

```dart
// main.dart
final PreferenciasService preferencias = await PreferenciasService.carregar();
runApp(EspacoCafeApp(preferencias: preferencias));

// AppBinding — ordem importa: SessionService lê PreferenciasService no construtor
Get.put(_preferencias, permanent: true);
Get.put(AuthService(), permanent: true);
Get.put(SessionService(), permanent: true);
```

`PreferenciasService` expõe getters síncronos (`ministerioAtivoId`) e escritas assíncronas
(`unawaited`, porque o usuário não precisa esperar o disco para trocar de ministério).

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Manter `get_storage`, abrir mão do wasm | O build JS funciona, mas fecharíamos a porta da TV/tablet sem ganho nenhum em troca. |
| `package:web` + `localStorage` direto | Menos dependência, mas amarra o código ao navegador — e o app pode virar mobile nativo depois. |
| Não persistir nada | O admin reescolheria o ministério a cada F5. Atrito diário por uma linha de código. |

## Consequências

**Positivas**
- `flutter build web --release --wasm` passa (validado em 2026-08-07).
- Uma dependência direta a menos no `pubspec.yaml`.
- `PreferenciasService` dá um lugar óbvio para futuras preferências locais.

**Negativas / riscos**
- O `main()` ganhou um `await` antes do `runApp` — poucos milissegundos, mas é trabalho no
  caminho crítico de inicialização.
- Ordem de registro no `AppBinding` passou a importar. Documentado com comentário no próprio
  arquivo, porque a falha seria um `Get.find` estourando em runtime, não em compilação.

**Nota para revisão futura**
Antes de adicionar qualquer pacote novo, rodar `flutter build web --wasm` e checar o *dry run*.
Uma dependência transitiva com `dart:html` bloqueia o wasm do app inteiro — e o aviso é fácil de
não ver no meio do log de build.
