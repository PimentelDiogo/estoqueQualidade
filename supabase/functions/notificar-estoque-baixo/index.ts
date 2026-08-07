// =============================================================================
// notificar-estoque-baixo
//
// Le os alertas abertos que ainda nao foram avisados, agrupa POR MINISTERIO e
// manda UM e-mail ao responsavel com a lista completa.
//
// O agrupamento e o ponto principal: um culto pode zerar cinco produtos. Sem
// agrupar, o responsavel receberia cinco e-mails e pararia de ler todos.
//
// Agendada por pg_cron (ver 20260807120400_cron.sql). Tambem pode ser chamada
// manualmente pelo app (botao "reenviar aviso").
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface AlertaPendente {
  alerta_id: string;
  produto_nome: string;
  quantidade: number;
  estoque_minimo: number;
  ministerio_id: string;
  ministerio_nome: string;
  responsavel_nome: string | null;
  responsavel_email: string | null;
}

const RESEND_ENDPOINT = 'https://api.resend.com/emails';

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      // service_role: precisa ler alertas de TODOS os ministerios, ignorando RLS.
      // Esta chave so existe no ambiente da Edge Function, nunca no app.
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const resendKey = Deno.env.get('RESEND_API_KEY');
    const remetente = Deno.env.get('EMAIL_REMETENTE') ??
      'Espaco Cafe <onboarding@resend.dev>';

    const { data, error } = await supabase
      .from('alerta_estoque')
      .select(`
        id,
        quantidade_no_disparo,
        estoque_minimo,
        ministerio_id,
        produto:produto_id ( nome ),
        ministerio:ministerio_id ( nome, responsavel_nome, responsavel_email )
      `)
      .eq('status', 'aberto')
      .is('email_enviado_em', null);

    if (error) throw error;

    const alertas: AlertaPendente[] = (data ?? []).map((row: any) => ({
      alerta_id: row.id,
      produto_nome: row.produto?.nome ?? 'Produto',
      quantidade: row.quantidade_no_disparo,
      estoque_minimo: row.estoque_minimo,
      ministerio_id: row.ministerio_id,
      ministerio_nome: row.ministerio?.nome ?? 'Ministerio',
      responsavel_nome: row.ministerio?.responsavel_nome ?? null,
      responsavel_email: row.ministerio?.responsavel_email ?? null,
    }));

    if (alertas.length === 0) {
      return json({ enviados: 0, mensagem: 'Nenhum alerta pendente.' });
    }

    // Agrupa por ministerio -> um e-mail por responsavel.
    const porMinisterio = new Map<string, AlertaPendente[]>();
    for (const a of alertas) {
      const lista = porMinisterio.get(a.ministerio_id) ?? [];
      lista.push(a);
      porMinisterio.set(a.ministerio_id, lista);
    }

    let enviados = 0;
    const idsMarcados: string[] = [];
    const semEmail: string[] = [];

    for (const [, itens] of porMinisterio) {
      const destino = itens[0].responsavel_email;

      // Sem e-mail cadastrado, o alerta continua PENDENTE de proposito: assim
      // ele sai assim que o admin preencher o e-mail, em vez de sumir calado.
      if (!destino) {
        semEmail.push(itens[0].ministerio_nome);
        continue;
      }

      if (!resendKey) {
        // Sem chave configurada nao mentimos dizendo que enviamos.
        return json(
          {
            erro: 'RESEND_API_KEY nao configurada',
            alertas_pendentes: alertas.length,
          },
          500,
        );
      }

      const resp = await fetch(RESEND_ENDPOINT, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: remetente,
          to: [destino],
          subject:
            `[${itens[0].ministerio_nome}] ${itens.length} produto(s) acabando`,
          html: montarHtml(itens),
        }),
      });

      if (!resp.ok) {
        console.error('Falha Resend:', resp.status, await resp.text());
        continue; // nao marca como enviado -> tenta de novo no proximo cron
      }

      enviados++;
      idsMarcados.push(...itens.map((i) => i.alerta_id));
    }

    if (idsMarcados.length > 0) {
      await supabase
        .from('alerta_estoque')
        .update({ email_enviado_em: new Date().toISOString() })
        .in('id', idsMarcados);
    }

    return json({
      enviados,
      alertas_marcados: idsMarcados.length,
      ministerios_sem_email: semEmail,
    });
  } catch (e) {
    console.error(e);
    return json({ erro: String(e) }, 500);
  }
});

function montarHtml(itens: AlertaPendente[]): string {
  const nome = itens[0].responsavel_nome ?? 'equipe';
  const linhas = itens
    .map((i) => {
      const esgotado = i.quantidade <= 0;
      const cor = esgotado ? '#D9534F' : '#E0A458';
      const situacao = esgotado ? 'ESGOTADO' : 'Acabando';
      return `
      <tr>
        <td style="padding:10px 12px;border-bottom:1px solid #eee">${i.produto_nome}</td>
        <td style="padding:10px 12px;border-bottom:1px solid #eee;text-align:center">
          <strong>${i.quantidade}</strong> / min. ${i.estoque_minimo}
        </td>
        <td style="padding:10px 12px;border-bottom:1px solid #eee;text-align:right;color:${cor}">
          <strong>${situacao}</strong>
        </td>
      </tr>`;
    })
    .join('');

  return `
  <div style="font-family:system-ui,-apple-system,sans-serif;max-width:560px;margin:0 auto">
    <div style="background:#0D0D0D;color:#F5F0F2;padding:20px 24px;border-radius:10px 10px 0 0">
      <h2 style="margin:0;font-size:18px">Espaco Cafe &middot; ${itens[0].ministerio_nome}</h2>
      <p style="margin:6px 0 0;color:#A8A0A3;font-size:14px">Aviso de estoque baixo</p>
    </div>
    <div style="border:1px solid #eee;border-top:none;border-radius:0 0 10px 10px;padding:20px 24px">
      <p style="font-size:15px">Ola, ${nome}. Estes produtos precisam de reposicao:</p>
      <table style="width:100%;border-collapse:collapse;font-size:14px">
        <thead>
          <tr style="text-align:left;color:#666;font-size:12px;text-transform:uppercase">
            <th style="padding:8px 12px">Produto</th>
            <th style="padding:8px 12px;text-align:center">Restante</th>
            <th style="padding:8px 12px;text-align:right">Situacao</th>
          </tr>
        </thead>
        <tbody>${linhas}</tbody>
      </table>
      <p style="color:#888;font-size:12px;margin-top:20px">
        Mensagem automatica do sistema do Espaco Cafe &mdash; PAES Lagoa.
      </p>
    </div>
  </div>`;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
