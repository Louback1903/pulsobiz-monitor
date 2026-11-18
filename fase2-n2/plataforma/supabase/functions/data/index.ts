// PulsoBiz Monitor - Edge Function "data" (Supabase).
//   POST /data               (header Device-Token)  recebe leituras do dispositivo e dispara alertas
//   GET  /data?variable=...  (header Device-Token)  le leituras (usado pelo app)
//   GET  /data?view=dashboard (publico, so leitura) dados do dashboard
// Mesma interface do contrato de dados (CONTRATO-DE-DADOS.md). Segredos vem de
// "Edge Functions > Secrets": SMTP_USER, SMTP_PASS, MAIL_TO, TWILIO_SID,
// TWILIO_TOKEN, TWILIO_FROM, SMS_TO.
import { createClient } from "jsr:@supabase/supabase-js@2";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, device-token, authorization",
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

let tokenCache: string | null = null;
async function tokenDoDispositivo(): Promise<string> {
  if (tokenCache) return tokenCache;
  const { data } = await sb.from("config").select("value").eq("key", "device_token").single();
  tokenCache = data?.value ?? "";
  return tokenCache!;
}

async function autorizado(req: Request): Promise<boolean> {
  const bruto = req.headers.get("device-token") ?? req.headers.get("authorization") ?? "";
  const enviado = bruto.replace(/^Bearer\s+/i, "").trim();
  const esperado = await tokenDoDispositivo();
  return esperado !== "" && enviado === esperado;
}

const hora = (d: Date) =>
  new Intl.DateTimeFormat("pt-BR", { hour: "2-digit", minute: "2-digit", timeZone: FUSO }).format(d);

// ---------- envio de e-mail (SMTP com TLS direto, porta 465) ----------
const b64 = (s: string) => btoa(String.fromCharCode(...new TextEncoder().encode(s)));

async function enviarEmail(assunto: string, texto: string): Promise<string> {
  const user = Deno.env.get("SMTP_USER"), pass = Deno.env.get("SMTP_PASS");
  const para = (Deno.env.get("MAIL_TO") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!user || !pass || para.length === 0) return "nao configurado";
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
async function enviarSms(texto: string): Promise<string> {
  const sid = Deno.env.get("TWILIO_SID"), token = Deno.env.get("TWILIO_TOKEN"), de = Deno.env.get("TWILIO_FROM");
  const para = (Deno.env.get("SMS_TO") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!sid || !token || !de || para.length === 0) return "nao configurado";
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

async function disparar(tipo: string, temperatura: number | null): Promise<unknown> {
  const desde = new Date(Date.now() - DEDUP_SEGUNDOS * 1000).toISOString();
  const { data: recente } = await sb.from("alert_log").select("id").eq("kind", tipo).gte("sent_at", desde).limit(1);
  if (recente && recente.length > 0) return "ignorado (alerta repetido em menos de 60 s)";
  const quando = hora(new Date());
  const texto = tipo === "alerta_temperatura"
    ? `PulsoBiz: temperatura alta no ambiente${temperatura !== null ? ` (${temperatura.toFixed(1)} C)` : ""} as ${quando}.`
    : `PulsoBiz: movimento detectado fora do expediente as ${quando}.`;
  const [email, sms] = await Promise.all([
    enviarEmail("PulsoBiz - " + ALERTAS[tipo], texto).catch((e) => "erro: " + (e as Error).message),
    enviarSms(texto).catch((e) => "erro: " + (e as Error).message),
  ]);
  await sb.from("alert_log").insert({ kind: tipo, email_status: String(email).slice(0, 200), sms_status: String(sms).slice(0, 200) });
  return { email, sms };
}

// ---------- POST: ingestao ----------
async function receber(req: Request): Promise<Response> {
  const bruto = await req.text();
  if (bruto.length > 20000) return json({ status: false, message: "payload grande demais" }, 413);
  let corpo: unknown;
  try { corpo = JSON.parse(bruto); } catch { return json({ status: false, message: "JSON invalido" }, 400); }
  const itens = (Array.isArray(corpo) ? corpo : [corpo]).slice(0, 50);
  const linhas: { variable: string; num: number | null; value: string; unit: string | null }[] = [];
  for (const it of itens as Record<string, unknown>[]) {
    const variable = String(it?.variable ?? "");
    if (!/^[a-z0-9_]{1,64}$/.test(variable) || it.value === undefined || it.value === null) {
      return json({ status: false, message: "item invalido: variable (a-z, 0-9, _) e value sao obrigatorios" }, 400);
    }
    const n = typeof it.value === "boolean" ? (it.value ? 1 : 0) : Number(it.value);
    linhas.push({
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
    if (ALERTAS[l.variable] && l.num === 1) alertas[l.variable] = await disparar(l.variable, temp);
  }
  return json({ status: true, result: `${linhas.length} Data Added`, ...(Object.keys(alertas).length ? { alertas } : {}) }, 201);
}

// ---------- GET: leitura para o app ----------
async function ler(url: URL): Promise<Response> {
  const variavel = url.searchParams.get("variable") ?? url.searchParams.get("variables") ?? "";
  if (!/^[a-z0-9_]{1,64}$/.test(variavel)) return json({ status: false, message: "informe variable" }, 400);
  const qty = Math.min(Math.max(parseInt(url.searchParams.get("qty") ?? "15") || 15, 1), 10000);
  const inicio = url.searchParams.get("start_date");
  const resultado: Record<string, unknown>[] = [];
  for (let off = 0; resultado.length < qty && off < 10000; off += 1000) {
    let q = sb.from("readings").select("id,variable,num,value,unit,created_at").eq("variable", variavel)
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

// ---------- GET: dados do dashboard (publico) ----------
async function dashboard(): Promise<Response> {
  const agora = new Date();
  const desde24 = new Date(agora.getTime() - 24 * 3600 * 1000);
  const desde24h = new Date(Math.floor(agora.getTime() / 3600000) * 3600000 - 23 * 3600000);
  const [ultimos, temp, umid, horas, alertasQ, nMov, nAlert] = await Promise.all([
    sb.rpc("latest_values"),
    sb.rpc("series_avg", { p_variable: "temperatura", p_since: desde24.toISOString(), p_bin: "10 minutes" }),
    sb.rpc("series_avg", { p_variable: "umidade", p_since: desde24.toISOString(), p_bin: "10 minutes" }),
    sb.rpc("hourly_counts", { p_since: desde24h.toISOString() }),
    sb.from("readings").select("variable,created_at").in("variable", Object.keys(ALERTAS)).eq("num", 1)
      .order("created_at", { ascending: false }).limit(30),
    sb.from("readings").select("id", { count: "exact", head: true }).eq("variable", "movimento").eq("num", 1).gte("created_at", desde24.toISOString()),
    sb.from("readings").select("id", { count: "exact", head: true }).in("variable", Object.keys(ALERTAS)).eq("num", 1).gte("created_at", desde24.toISOString()),
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

  return json({
    status: true,
    now: agora.toISOString(),
    latest,
    series: { temperatura: tempPts, umidade: serie(umid.data) },
    hourly,
    alerts: (alertasQ.data ?? []).map((a) => ({ t: a.created_at, text: ALERTAS[a.variable] })),
    totals: { movimentos: nMov.count ?? 0, alertas: nAlert.count ?? 0, temperaturaMedia: media },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  const url = new URL(req.url);
  try {
    if (req.method === "GET" && url.searchParams.get("view") === "dashboard") return await dashboard();
    if (!(await autorizado(req))) return json({ status: false, message: "token invalido" }, 401);
    if (req.method === "POST") return await receber(req);
    if (req.method === "GET") return await ler(url);
    return json({ status: false, message: "metodo nao suportado" }, 405);
  } catch (e) {
    return json({ status: false, message: "erro interno: " + (e as Error).message }, 500);
  }
});
