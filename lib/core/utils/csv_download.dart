import 'dart:convert';

import 'package:web/web.dart' as web;

/// Dispara o download de um CSV no navegador.
///
/// Isolado num arquivo proprio para ser o **unico** ponto do app que toca a API
/// do navegador — o resto do codigo continua agnostico de plataforma.
///
/// O BOM UTF-8 no inicio nao e decoracao: sem ele o Excel em Windows abre
/// "Cafe expresso" como "CafÃ© expresso".
void baixarCsv({required String conteudo, required String nomeArquivo}) {
  const String bom = '﻿';

  final String dataUrl =
      'data:text/csv;charset=utf-8;base64,'
      '${base64Encode(utf8.encode(bom + conteudo))}';

  final web.HTMLAnchorElement link =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = dataUrl
        ..download = nomeArquivo;

  web.document.body?.append(link);
  link.click();
  link.remove();
}
