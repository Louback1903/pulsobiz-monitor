// PulsoBiz Monitor - Edge Function "data" (Supabase), multi-loja.
//   POST /data                       (Device-Token da loja)  recebe leituras e dispara alertas
//   GET  /data?variable=...          (Device-Token ou login)  le leituras da loja
//   GET  /data?view=dashboard        (login do cliente; sem login so para a loja de demonstracao)
//   POST /data?admin=<acao>          (X-Admin-Token)  criar_cliente, redefinir_senha, listar
// Cada cliente (loja) so enxerga os proprios dados: o login (JWT do Supabase Auth) e ligado a uma loja
// pela tabela "membros". O acesso ao banco e sempre pela service role, dentro desta funcao.
import { createClient } from "jsr:@supabase/supabase-js@2";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, device-token, authorization, x-admin-token, apikey",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });

const ALERTAS: Record<string, string> = {
  alerta_temperatura: "Temperatura alta no ambiente",
  alerta_fora_horario: "Movimento fora do expediente",
};
const DEDUP_SEGUNDOS = 60;
const FUSO = "America/Recife";

type Loja = {
  id: string; nome: string; device_token: string; dashboard_publico: boolean;
  alert_emails: string | null; alert_sms: string | null; lotacao: number; meta_pendente: boolean;
};
const COLS = "id,nome,device_token,dashboard_publico,alert_emails,alert_sms,lotacao,meta_pendente";

// ---------- quem esta chamando ----------
function credencial(req: Request): { tipo: "token" | "jwt" | "nenhuma"; valor: string } {
  const dt = (req.headers.get("device-token") ?? "").trim();
  if (dt) return { tipo: "token", valor: dt };
  const bearer = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!bearer) return { tipo: "nenhuma", valor: "" };
  return bearer.split(".").length === 3 ? { tipo: "jwt", valor: bearer } : { tipo: "token", valor: bearer };
}

async function lojaPorToken(token: string): Promise<Loja | null> {
  if (!token) return null;
  const { data } = await sb.from("lojas").select(COLS).eq("device_token", token).maybeSingle();
  return (data as Loja) ?? null;
}

async function lojaPorJwt(jwt: string): Promise<Loja | null> {
  const { data: u, error } = await sb.auth.getUser(jwt);
  if (error || !u?.user) return null;
  const { data: m } = await sb.from("membros").select("loja_id").eq("user_id", u.user.id).limit(1).maybeSingle();
  if (!m) return null;
  const { data } = await sb.from("lojas").select(COLS).eq("id", m.loja_id).maybeSingle();
  return (data as Loja) ?? null;
}

async function lojaPublica(): Promise<Loja | null> {
  const { data } = await sb.from("lojas").select(COLS).eq("dashboard_publico", true).limit(1).maybeSingle();
  return (data as Loja) ?? null;
}

const hora = (d: Date) =>
  new Intl.DateTimeFormat("pt-BR", { hour: "2-digit", minute: "2-digit", timeZone: FUSO }).format(d);

const lista = (s: string | null | undefined) => (s ?? "").split(",").map((x) => x.trim()).filter(Boolean);
// Destinatarios: os da propria loja; a loja de demonstracao usa tambem os segredos globais.
const destinosEmail = (l: Loja) => lista(l.alert_emails).length ? lista(l.alert_emails) : (l.dashboard_publico ? lista(Deno.env.get("MAIL_TO")) : []);
const destinosSms = (l: Loja) => lista(l.alert_sms).length ? lista(l.alert_sms) : (l.dashboard_publico ? lista(Deno.env.get("SMS_TO")) : []);

// ---------- envio de e-mail (SMTP com TLS direto, porta 465) ----------
const b64 = (s: string) => btoa(String.fromCharCode(...new TextEncoder().encode(s)));

async function enviarEmail(assunto: string, texto: string, para: string[]): Promise<string> {
  const user = Deno.env.get("SMTP_USER"), pass = Deno.env.get("SMTP_PASS");
  if (!user || !pass) return "nao configurado";
  if (para.length === 0) return "sem destinatarios";
  const enc = new TextEncoder(), dec = new TextDecoder();
  const conn = await Deno.connectTls({ hostname: "smtp.gmail.com", port: 465 });
  let pendente = "";
  const resposta = async (): Promise<string> => {
    while (true) {
      const linhas = pendente.split("\r\n");
      const completas = linhas.slice(0, -1);
      const i = completas.findIndex((l) => /^\d{3} /.test(l));
      if (i >= 0) {
        pendente = linhas.slice(i + 1).join("\r\n");
        return completas.slice(0, i + 1).join("\n");
      }
      const buf = new Uint8Array(4096);
      const n = await conn.read(buf);
      if (n === null) throw new Error("conexao SMTP fechada");
      pendente += dec.decode(buf.subarray(0, n));
    }
  };
  const cmd = async (linha: string, ok: number[], rotulo: string) => {
    await conn.write(enc.encode(linha + "\r\n"));
    const r = await resposta();
    const codigo = parseInt(r.split("\n").pop()!.slice(0, 3));
    if (!ok.includes(codigo)) throw new Error(`SMTP ${rotulo}: ${r}`);
  };
  try {
    const saudacao = await resposta();
    if (!saudacao.startsWith("220")) throw new Error("SMTP saudacao: " + saudacao);
    await cmd("EHLO pulsobiz", [250], "EHLO");
    await cmd("AUTH LOGIN", [334], "AUTH");
    await cmd(b64(user), [334], "usuario");
    await cmd(b64(pass), [235], "senha (confira SMTP_USER e SMTP_PASS)");
    await cmd(`MAIL FROM:<${user}>`, [250], "MAIL FROM");
    for (const p of para) await cmd(`RCPT TO:<${p}>`, [250, 251], "RCPT TO");
    await cmd("DATA", [354], "DATA");
    const corpo = b64(texto).match(/.{1,76}/g)!.join("\r\n");
    const msg = [
      `From: "PulsoBiz Monitor" <${user}>`,
      `To: ${para.join(", ")}`,
      `Subject: =?UTF-8?B?${b64(assunto)}?=`,
      "MIME-Version: 1.0",
      "Content-Type: text/plain; charset=UTF-8",
      "Content-Transfer-Encoding: base64",
      "",
      corpo,
    ].join("\r\n");
    await cmd(msg + "\r\n.", [250], "envio");
    await cmd("QUIT", [221], "QUIT").catch(() => {});
    return "enviado";
  } finally {
    try { conn.close(); } catch { /* ja fechada */ }
  }
}

// ---------- envio de SMS (Twilio) ----------
async function enviarSms(texto: string, para: string[]): Promise<string> {
  const sid = Deno.env.get("TWILIO_SID"), token = Deno.env.get("TWILIO_TOKEN"), de = Deno.env.get("TWILIO_FROM");
  if (!sid || !token || !de) return "nao configurado";
  if (para.length === 0) return "sem destinatarios";
  const erros: string[] = [];
  let ok = 0;
  const enviar = (numero: string, corpo: string) =>
    fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: {
        Authorization: "Basic " + btoa(`${sid}:${token}`),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: numero, From: de, Body: corpo }),
    });
  for (const numero of para) {
    let r = await enviar(numero, texto);
    let obs = "";
    // Conta de teste do Twilio so aceita modelos prontos: usa o modelo de alerta.
    if (!r.ok) {
      const detalhe = await r.text();
      if (detalhe.includes("572006")) {
        r = await enviar(numero, "sms_internal_alerts");
        obs = " (modelo de teste)";
      } else {
        erros.push(`${numero.slice(0, 5)}...: HTTP ${r.status} ${detalhe.slice(0, 120)}`);
        continue;
      }
    }
    if (r.ok) ok++;
    else erros.push(`${numero.slice(0, 5)}...: HTTP ${r.status} ${(await r.text()).slice(0, 120)}${obs}`);
  }
  return erros.length ? `enviados ${ok}/${para.length}; erros: ${erros.join(" | ")}` : `enviados ${ok}/${para.length}`;
}

async function disparar(loja: Loja, tipo: string, temperatura: number | null): Promise<unknown> {
  const desde = new Date(Date.now() - DEDUP_SEGUNDOS * 1000).toISOString();
  const { data: recente } = await sb.from("alert_log").select("id").eq("loja_id", loja.id).eq("kind", tipo).gte("sent_at", desde).limit(1);
  if (recente && recente.length > 0) return "ignorado (alerta repetido em menos de 60 s)";
  const quando = hora(new Date());
  const texto = tipo === "alerta_temperatura"
    ? `PulsoBiz - ${loja.nome}: temperatura alta no ambiente${temperatura !== null ? ` (${temperatura.toFixed(1)} C)` : ""} as ${quando}.`
    : `PulsoBiz - ${loja.nome}: movimento detectado fora do expediente as ${quando}.`;
  const [email, sms] = await Promise.all([
    enviarEmail(`PulsoBiz - ${ALERTAS[tipo]} (${quando})`, texto, destinosEmail(loja)).catch((e) => "erro: " + (e as Error).message),
    enviarSms(texto, destinosSms(loja)).catch((e) => "erro: " + (e as Error).message),
  ]);
  await sb.from("alert_log").insert({ loja_id: loja.id, kind: tipo, email_status: String(email).slice(0, 200), sms_status: String(sms).slice(0, 200) });
  return { email, sms };
}

// ---------- lotacao e temperatura ideal ----------
// entrada soma 1, saida subtrai 1 (nunca abaixo de zero). A temperatura ideal cai
// IDEAL_POR_PESSOA graus por pessoa, ate o piso IDEAL_MIN.
const IDEAL_BASE = 25, IDEAL_POR_PESSOA = 0.5, IDEAL_MIN = 21, TOLERANCIA = 0.5;
const idealPara = (n: number) => Math.max(IDEAL_MIN, Math.round((IDEAL_BASE - IDEAL_POR_PESSOA * n) * 10) / 10);

async function emailLotacao(loja: Loja, tipo: string, assunto: string, texto: string): Promise<string> {
  // trava de seguranca: no maximo 20 e-mails desse tipo em 10 minutos por loja
  const desde = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const { count } = await sb.from("alert_log").select("id", { count: "exact", head: true }).eq("loja_id", loja.id).eq("kind", tipo).gte("sent_at", desde);
  if ((count ?? 0) >= 20) return "ignorado (limite de e-mails)";
  const r = await enviarEmail(assunto, texto, destinosEmail(loja)).catch((e) => "erro: " + (e as Error).message);
  await sb.from("alert_log").insert({ loja_id: loja.id, kind: tipo, email_status: String(r).slice(0, 200) });
  return r;
}

async function atualizarLotacao(loja: Loja, linhas: { variable: string; num: number | null }[]): Promise<unknown> {
  let delta = 0, zerar = false, entrou = false;
  for (const l of linhas) {
    if (l.variable === "entrada" && l.num === 1) { delta++; entrou = true; }
    else if (l.variable === "saida" && l.num === 1) delta--;
    else if (l.variable === "lotacao_reset" && l.num === 1) zerar = true;
  }
  if (delta === 0 && !zerar) return null;
  const { data: atual } = await sb.from("lojas").select("lotacao").eq("id", loja.id).single();
  const antes = atual?.lotacao ?? 0;
  const depois = zerar ? 0 : Math.max(0, antes + delta);
  if (depois === antes) return { lotacao: depois, mudou: false };
  const idealDepois = idealPara(depois);
  const mudouMeta = idealDepois !== idealPara(antes);
  await sb.from("lojas").update({ lotacao: depois, ...(mudouMeta ? { meta_pendente: true } : {}) }).eq("id", loja.id);
  const quando = hora(new Date());
  const quem = zerar ? "Lotação zerada" : entrou ? "Entrou alguém" : "Saiu alguém";
  const texto = `PulsoBiz - ${loja.nome}: ${quem} às ${quando}.\nLotação agora: ${depois} ${depois === 1 ? "pessoa" : "pessoas"}.\n` +
    `Temperatura ideal para essa lotação: ${idealDepois.toFixed(1)} °C.`;
  const email = await emailLotacao(loja, "lotacao", `PulsoBiz - Lotação ${depois} (${quando})`, texto);
  return { lotacao: depois, ideal: idealDepois, email };
}

async function verificarEstabilizacao(loja: Loja): Promise<unknown> {
  const { data: l } = await sb.from("lojas").select("lotacao,meta_pendente").eq("id", loja.id).single();
  if (!l?.meta_pendente) return null;
  const n = l.lotacao ?? 0, alvo = idealPara(n);
  const { data } = await sb.from("readings").select("num").eq("loja_id", loja.id).eq("variable", "temperatura")
    .order("created_at", { ascending: false }).limit(3);
  if (!data || data.length < 3 || data.some((r) => r.num === null || Math.abs(r.num - alvo) > TOLERANCIA)) return null;
  await sb.from("lojas").update({ meta_pendente: false }).eq("id", loja.id);
  const quando = hora(new Date());
  const texto = `PulsoBiz - ${loja.nome}: temperatura estabilizada em ${alvo.toFixed(1)} °C às ${quando}.\n` +
    `É a temperatura ideal para ${n} ${n === 1 ? "pessoa" : "pessoas"} na loja.`;
  const email = await emailLotacao(loja, "estabilizada", `PulsoBiz - Temperatura estabilizada em ${alvo.toFixed(1)} °C (${quando})`, texto);
  return { estabilizada: alvo, email };
}

// ---------- POST: ingestao (so dispositivos, pelo token da loja) ----------
async function receber(req: Request, loja: Loja): Promise<Response> {
  const bruto = await req.text();
  if (bruto.length > 20000) return json({ status: false, message: "payload grande demais" }, 413);
  let corpo: unknown;
  try { corpo = JSON.parse(bruto); } catch { return json({ status: false, message: "JSON invalido" }, 400); }
  const itens = (Array.isArray(corpo) ? corpo : [corpo]).slice(0, 50);
  const linhas: { loja_id: string; variable: string; num: number | null; value: string; unit: string | null }[] = [];
  for (const it of itens as Record<string, unknown>[]) {
    const variable = String(it?.variable ?? "");
    if (!/^[a-z0-9_]{1,64}$/.test(variable) || it.value === undefined || it.value === null) {
      return json({ status: false, message: "item invalido: variable (a-z, 0-9, _) e value sao obrigatorios" }, 400);
    }
    const n = typeof it.value === "boolean" ? (it.value ? 1 : 0) : Number(it.value);
    linhas.push({
      loja_id: loja.id,
      variable,
      num: Number.isFinite(n) ? n : null,
      value: String(it.value).slice(0, 200),
      unit: it.unit ? String(it.unit).slice(0, 16) : null,
    });
  }
  if (linhas.length === 0) return json({ status: false, message: "nenhum dado" }, 400);
  const { error } = await sb.from("readings").insert(linhas);
  if (error) return json({ status: false, message: error.message }, 500);

  const temp = linhas.find((l) => l.variable === "temperatura")?.num ?? null;
  const alertas: Record<string, unknown> = {};
  for (const l of linhas) {
    if (ALERTAS[l.variable] && l.num === 1) alertas[l.variable] = await disparar(loja, l.variable, temp);
  }
  const lotacao = await atualizarLotacao(loja, linhas);
  const estab = linhas.some((l) => l.variable === "temperatura") ? await verificarEstabilizacao(loja) : null;
  return json({
    status: true,
    result: `${linhas.length} Data Added`,
    ...(Object.keys(alertas).length ? { alertas } : {}),
    ...(lotacao ? { lotacao } : {}),
    ...(estab ? { estabilizacao: estab } : {}),
  }, 201);
}

// ---------- GET: leitura (app e integracoes) ----------
async function ler(url: URL, loja: Loja): Promise<Response> {
  const variavel = url.searchParams.get("variable") ?? url.searchParams.get("variables") ?? "";
  if (!/^[a-z0-9_]{1,64}$/.test(variavel)) return json({ status: false, message: "informe variable" }, 400);
  const qty = Math.min(Math.max(parseInt(url.searchParams.get("qty") ?? "15") || 15, 1), 10000);
  const inicio = url.searchParams.get("start_date");
  const resultado: Record<string, unknown>[] = [];
  for (let off = 0; resultado.length < qty && off < 10000; off += 1000) {
    let q = sb.from("readings").select("id,variable,num,value,unit,created_at").eq("loja_id", loja.id).eq("variable", variavel)
      .order("created_at", { ascending: false }).range(off, off + 999);
    if (inicio) q = q.gte("created_at", inicio);
    const { data, error } = await q;
    if (error) return json({ status: false, message: error.message }, 500);
    for (const r of data ?? []) {
      resultado.push({ id: r.id, variable: r.variable, value: r.num ?? r.value, unit: r.unit, time: r.created_at });
    }
    if (!data || data.length < 1000) break;
  }
  return json({ status: true, result: resultado.slice(0, qty) });
}

// ---------- GET: dados do dashboard ----------
async function dashboard(loja: Loja): Promise<Response> {
  const agora = new Date();
  const desde24 = new Date(agora.getTime() - 24 * 3600 * 1000);
  const desde24h = new Date(Math.floor(agora.getTime() / 3600000) * 3600000 - 23 * 3600000);
  const [ultimos, temp, umid, horas, alertasQ, nMov, nAlert, atual] = await Promise.all([
    sb.rpc("latest_values", { p_loja: loja.id }),
    sb.rpc("series_avg", { p_loja: loja.id, p_variable: "temperatura", p_since: desde24.toISOString(), p_bin: "10 minutes" }),
    sb.rpc("series_avg", { p_loja: loja.id, p_variable: "umidade", p_since: desde24.toISOString(), p_bin: "10 minutes" }),
    sb.rpc("hourly_counts", { p_loja: loja.id, p_since: desde24h.toISOString() }),
    sb.from("readings").select("variable,created_at").eq("loja_id", loja.id).in("variable", Object.keys(ALERTAS)).eq("num", 1)
      .order("created_at", { ascending: false }).limit(30),
    sb.from("readings").select("id", { count: "exact", head: true }).eq("loja_id", loja.id).eq("variable", "movimento").eq("num", 1).gte("created_at", desde24.toISOString()),
    sb.from("readings").select("id", { count: "exact", head: true }).eq("loja_id", loja.id).in("variable", Object.keys(ALERTAS)).eq("num", 1).gte("created_at", desde24.toISOString()),
    sb.from("lojas").select("lotacao,meta_pendente").eq("id", loja.id).single(),
  ]);
  const latest: Record<string, { v: number | string; t: string; u: string | null }> = {};
  for (const r of ultimos.data ?? []) latest[r.variable] = { v: r.num ?? r.value, t: r.created_at, u: r.unit };

  const porHora = new Map<number, number>();
  for (const r of horas.data ?? []) porHora.set(new Date(r.h).getTime(), Number(r.n));
  const hourly = Array.from({ length: 24 }, (_, k) => {
    const ini = new Date(desde24h.getTime() + k * 3600000);
    const label = new Intl.DateTimeFormat("pt-BR", { hour: "2-digit", hour12: false, timeZone: FUSO }).format(ini);
    return { label: label.padStart(2, "0") + "h", count: porHora.get(ini.getTime()) ?? 0 };
  });
  const serie = (d: { t: string; v: number }[] | null) => (d ?? []).map((p) => [new Date(p.t).getTime(), Math.round(p.v * 10) / 10]);
  const tempPts = serie(temp.data);
  const media = tempPts.length ? Math.round((tempPts.reduce((s, p) => s + p[1], 0) / tempPts.length) * 10) / 10 : null;

  const lot = atual.data?.lotacao ?? 0;
  return json({
    status: true,
    now: agora.toISOString(),
    loja: { nome: loja.nome },
    meta: { lotacao: lot, ideal: idealPara(lot), estabilizada: !(atual.data?.meta_pendente ?? false) },
    latest,
    series: { temperatura: tempPts, umidade: serie(umid.data) },
    hourly,
    alerts: (alertasQ.data ?? []).map((a) => ({ t: a.created_at, text: ALERTAS[a.variable] })),
    totals: { movimentos: nMov.count ?? 0, alertas: nAlert.count ?? 0, temperaturaMedia: media },
  });
}

// ---------- administracao (so a PulsoBiz, com X-Admin-Token) ----------
async function admin(req: Request, url: URL): Promise<Response> {
  const segredo = Deno.env.get("ADMIN_TOKEN") ?? "";
  if (!segredo || (req.headers.get("x-admin-token") ?? "") !== segredo) return json({ status: false, message: "nao autorizado" }, 401);
  if (req.method !== "POST") return json({ status: false, message: "use POST" }, 405);
  const acao = url.searchParams.get("admin");
  const c = await req.json().catch(() => ({})) as Record<string, unknown>;
  const emailOk = (e: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);

  if (acao === "listar") {
    const { data } = await sb.from("lojas").select("id,nome,criado_em,lotacao,dashboard_publico").order("criado_em");
    return json({ status: true, lojas: data ?? [] });
  }

  if (acao === "criar_cliente") {
    const nome = String(c.nome ?? "").trim(), email = String(c.email ?? "").trim().toLowerCase(), senha = String(c.senha ?? "");
    if (nome.length < 2 || nome.length > 80) return json({ status: false, message: "nome invalido" }, 400);
    if (!emailOk(email)) return json({ status: false, message: "e-mail invalido" }, 400);
    if (senha.length < 8) return json({ status: false, message: "a senha precisa ter pelo menos 8 caracteres" }, 400);
    const { data: loja, error } = await sb.from("lojas")
      .insert({ nome, alert_emails: String(c.alert_emails ?? "").trim() || email, alert_sms: String(c.alert_sms ?? "").trim() || null })
      .select(COLS).single();
    if (error || !loja) return json({ status: false, message: error?.message ?? "erro ao criar loja" }, 500);
    const { data: u, error: e2 } = await sb.auth.admin.createUser({ email, password: senha, email_confirm: true });
    if (e2 || !u?.user) {
      await sb.from("lojas").delete().eq("id", loja.id);
      return json({ status: false, message: e2?.message ?? "erro ao criar usuario" }, 400);
    }
    await sb.from("membros").insert({ user_id: u.user.id, loja_id: loja.id });
    return json({ status: true, loja_id: loja.id, nome, email, device_token: loja.device_token }, 201);
  }

  if (acao === "redefinir_senha") {
    const email = String(c.email ?? "").trim().toLowerCase(), senha = String(c.senha ?? "");
    if (!emailOk(email) || senha.length < 8) return json({ status: false, message: "informe e-mail e senha (minimo 8 caracteres)" }, 400);
    const { data } = await sb.auth.admin.listUsers({ page: 1, perPage: 1000 });
    const u = data?.users.find((x) => (x.email ?? "").toLowerCase() === email);
    if (!u) return json({ status: false, message: "usuario nao encontrado" }, 404);
    const { error } = await sb.auth.admin.updateUserById(u.id, { password: senha });
    return error ? json({ status: false, message: error.message }, 400) : json({ status: true, email });
  }

  return json({ status: false, message: "acao desconhecida" }, 400);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  const url = new URL(req.url);
  try {
    if (url.searchParams.get("admin")) return await admin(req, url);

    const cred = credencial(req);
    let loja: Loja | null = null;
    if (cred.tipo === "token") loja = await lojaPorToken(cred.valor);
    else if (cred.tipo === "jwt") loja = await lojaPorJwt(cred.valor);

    if (req.method === "GET" && url.searchParams.get("view") === "dashboard") {
      if (!loja && cred.tipo === "nenhuma") loja = await lojaPublica(); // demonstracao aberta
      if (!loja) return json({ status: false, message: "nao autorizado" }, 401);
      return await dashboard(loja);
    }
    if (!loja) return json({ status: false, message: "nao autorizado" }, 401);
    if (req.method === "POST") {
      if (cred.tipo !== "token") return json({ status: false, message: "somente dispositivos enviam dados" }, 403);
      return await receber(req, loja);
    }
    if (req.method === "GET") return await ler(url, loja);
    return json({ status: false, message: "metodo nao suportado" }, 405);
  } catch (e) {
    return json({ status: false, message: "erro interno: " + (e as Error).message }, 500);
  }
});
