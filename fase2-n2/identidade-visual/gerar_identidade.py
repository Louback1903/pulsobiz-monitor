"""Gera a identidade visual da PulsoBiz: logo (SVG) e icones (PNG).

Simbolo: um pulso (batimento) dentro de um selo escuro. Cores: verde #43D17A sobre azul-esverdeado escuro.
Uso:  python gerar_identidade.py        (gera os arquivos nesta pasta)
"""
import os
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
VERDE = (67, 209, 122)
VERDE_CLARO = (140, 240, 180)
FUNDO_A = (16, 38, 28)   # topo do degrade
FUNDO_B = (7, 18, 14)    # base do degrade
AZUL = (79, 195, 247)

# Pulso em coordenadas de 0 a 100 (x, y)
PULSO = [(10, 54), (31, 54), (39, 38), (49, 76), (61, 19), (71, 62), (77, 54), (90, 54)]


def degrade(tam):
    img = Image.new("RGB", (tam, tam))
    px = img.load()
    for y in range(tam):
        t = y / (tam - 1)
        c = tuple(int(FUNDO_A[i] * (1 - t) + FUNDO_B[i] * t) for i in range(3))
        for x in range(tam):
            px[x, y] = c
    return img


def desenhar_pulso(draw, tam, margem, largura, cor):
    esc = (tam - 2 * margem) / 100.0
    pts = [(margem + x * esc, margem + y * esc) for x, y in PULSO]
    draw.line(pts, fill=cor, width=int(largura), joint="curve")
    r = largura / 2
    for p in (pts[0], pts[-1]):
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=cor)
    return pts


def simbolo(tam=1024, com_fundo=True, margem_pulso=0.2, arredondar=0.22, anel=True):
    """Simbolo completo. com_fundo=False devolve so o desenho (fundo transparente)."""
    ss = 3  # supersampling para bordas suaves
    T = tam * ss
    base = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    if com_fundo:
        fundo = degrade(T).convert("RGBA")
        mascara = Image.new("L", (T, T), 0)
        ImageDraw.Draw(mascara).rounded_rectangle([0, 0, T - 1, T - 1], radius=int(T * arredondar), fill=255)
        base.paste(fundo, (0, 0), mascara)
    d = ImageDraw.Draw(base)
    if anel:
        e = int(T * 0.075)
        d.ellipse([e, e, T - e, T - e], outline=VERDE + (70,), width=int(T * 0.012))
    m = int(T * margem_pulso)
    # brilho suave atras do pulso
    brilho = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    desenhar_pulso(ImageDraw.Draw(brilho), T, m, T * 0.075, VERDE + (90,))
    from PIL import ImageFilter
    brilho = brilho.filter(ImageFilter.GaussianBlur(T * 0.02))
    base.alpha_composite(brilho)
    d = ImageDraw.Draw(base)
    desenhar_pulso(d, T, m, T * 0.052, VERDE)
    desenhar_pulso(d, T, m, T * 0.018, VERDE_CLARO)
    return base.resize((tam, tam), Image.LANCZOS)


def salvar(img, nome):
    caminho = os.path.join(AQUI, nome)
    img.save(caminho)
    print("gerado", nome, img.size)


def main():
    salvar(simbolo(1024, True), "icone-1024.png")                       # icone completo (loja/atalho)
    salvar(simbolo(432, True, 0.2, 0.0), "icone-adaptativo-fundo.png")  # nao usado; referencia
    # Camada frontal do icone adaptativo do Android: pulso centralizado na zona segura (66%), fundo transparente
    frente = simbolo(1024, False, margem_pulso=0.30, anel=False)
    salvar(frente, "icone-adaptativo-frente.png")
    salvar(simbolo(512, False, margem_pulso=0.14, anel=True), "simbolo-512.png")  # simbolo para dentro do app
    salvar(simbolo(192, True), "icone-192.png")
    salvar(simbolo(48, True, arredondar=0.2), "favicon-48.png")

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 160" role="img" aria-label="PulsoBiz">
  <defs>
    <linearGradient id="fundo" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#10261c"/><stop offset="1" stop-color="#07120e"/>
    </linearGradient>
    <filter id="brilho" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
  </defs>
  <rect x="8" y="8" width="144" height="144" rx="32" fill="url(#fundo)"/>
  <circle cx="80" cy="80" r="62" fill="none" stroke="#43d17a" stroke-opacity=".28" stroke-width="2"/>
  <polyline points="{' '.join(f'{22 + x * 1.16:.1f},{22 + y * 1.16:.1f}' for x, y in PULSO)}"
            fill="none" stroke="#43d17a" stroke-opacity=".5" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" filter="url(#brilho)"/>
  <polyline points="{' '.join(f'{22 + x * 1.16:.1f},{22 + y * 1.16:.1f}' for x, y in PULSO)}"
            fill="none" stroke="#43d17a" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
  <polyline points="{' '.join(f'{22 + x * 1.16:.1f},{22 + y * 1.16:.1f}' for x, y in PULSO)}"
            fill="none" stroke="#8cf0b4" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
  <text x="176" y="98" font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif" font-size="68" font-weight="700" fill="#e8f3ec">Pulso<tspan fill="#43d17a">Biz</tspan></text>
  <text x="178" y="130" font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif" font-size="22" letter-spacing="4" fill="#8fa99a">MONITOR</text>
</svg>
"""
    with open(os.path.join(AQUI, "logo.svg"), "w", encoding="utf-8") as f:
        f.write(svg)
    print("gerado logo.svg")


if __name__ == "__main__":
    main()
