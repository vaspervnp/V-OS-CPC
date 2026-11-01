#!/usr/bin/env python3
"""mkdocs - the V-OS manual as one PDF.

usage: mkdocs.py out.pdf [en|fr|es|de|it]

Reads docs/manual/*.md in order (Greek; with a language code,
docs/manual/<code>/*.md), with sdk/README.md (sdk/README.<code>.md) as
chapter 7 (before 08-...), turns them into HTML (python markdown) and lays them out with
PyMuPDF's Story on A4 pages, in Noto Sans: a title page, a contents
page, the chapters (each on a new page), page numbers and bookmarks.
Links to other chapters become plain text; web links stay links.
"""
import glob
import html
import os
import re
import sys

import fitz
import markdown

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FONTS = "/usr/share/fonts/truetype/noto"
PAGE = fitz.paper_rect("a4")
BODY = PAGE + (56, 60, -56, -64)

CSS = """
@font-face {font-family: sans; src: url(NotoSans-Regular.ttf);}
@font-face {font-family: sans; src: url(NotoSans-Bold.ttf); font-weight: bold;}
@font-face {font-family: sans; src: url(NotoSans-Italic.ttf); font-style: italic;}
@font-face {font-family: mono; src: url(NotoSansMono-Regular.ttf);}
@font-face {font-family: mono; src: url(NotoSansMono-Bold.ttf); font-weight: bold;}
body {font-family: sans; font-size: 10pt; line-height: 1.35; color: #1d2030;}
h1 {font-size: 20pt; color: #1b2a8a; margin-top: 0; margin-bottom: 10pt;}
h2 {font-size: 14pt; color: #1b2a8a; margin-top: 14pt; margin-bottom: 4pt;}
h3 {font-size: 11.5pt; color: #2d3a9a; margin-top: 10pt; margin-bottom: 3pt;}
p, li {margin-top: 2pt; margin-bottom: 4pt;}
code {font-family: mono; font-size: 9pt; color: #6a1b52;}
pre {font-family: mono; font-size: 8.5pt; background-color: #eef0f8; padding: 6pt;
     margin-top: 4pt; margin-bottom: 6pt;}
pre code {color: #1d2030;}
table {border-collapse: collapse; width: 100%; margin-top: 4pt; margin-bottom: 8pt;}
th {background-color: #dde1f3; font-weight: bold; text-align: left;}
th, td {border: 0.5pt solid #9aa0c0; padding: 2pt 4pt; font-size: 9pt; vertical-align: top;}
blockquote {margin-left: 10pt; padding-left: 8pt; color: #3a3f5a; border-left: 2pt solid #9aa0c0;}
a {color: #1b2a8a;}
.title {font-size: 48pt; font-weight: bold; color: #1b2a8a; margin-top: 180pt;}
.subtitle {font-size: 16pt; margin-top: 6pt;}
.small {font-size: 10pt; color: #5a6080; margin-top: 30pt;}
"""


WORDS = {
    "el": dict(sdk="README.md", contents="Περιεχόμενα", docs="Τεκμηρίωση",
               subtitle="Γραφικό λειτουργικό σύστημα για τον Amstrad CPC 6128",
               made="Φτιαγμένο από τα docs/manual/*.md και το sdk/README.md "
                    "με το tools/mkdocs.py (make docs).", title="V-OS: Τεκμηρίωση"),
    "en": dict(sdk="README.en.md", contents="Contents", docs="Manual",
               subtitle="A graphical operating system for the Amstrad CPC 6128",
               made="Made from docs/manual/en/*.md and sdk/README.en.md "
                    "by tools/mkdocs.py (make docs).", title="V-OS Manual"),
    "fr": dict(sdk="README.fr.md", contents="Sommaire", docs="Manuel",
               subtitle="Un système d'exploitation graphique pour l'Amstrad CPC 6128",
               made="Fait à partir de docs/manual/fr/*.md et sdk/README.fr.md "
                    "par tools/mkdocs.py (make docs).", title="Manuel de V-OS"),
    "es": dict(sdk="README.es.md", contents="Índice", docs="Manual",
               subtitle="Un sistema operativo gráfico para el Amstrad CPC 6128",
               made="Hecho a partir de docs/manual/es/*.md y sdk/README.es.md "
                    "con tools/mkdocs.py (make docs).", title="Manual de V-OS"),
    "de": dict(sdk="README.de.md", contents="Inhalt", docs="Handbuch",
               subtitle="Ein grafisches Betriebssystem für den Amstrad CPC 6128",
               made="Erstellt aus docs/manual/de/*.md und sdk/README.de.md "
                    "mit tools/mkdocs.py (make docs).", title="V-OS Handbuch"),
    "it": dict(sdk="README.it.md", contents="Indice", docs="Manuale",
               subtitle="Un sistema operativo grafico per l'Amstrad CPC 6128",
               made="Generato da docs/manual/it/*.md e sdk/README.it.md "
                    "con tools/mkdocs.py (make docs).", title="Manuale di V-OS"),
}


def chapters(lang):
    folder = os.path.join(ROOT, "docs", "manual", *([lang] if lang != "el" else []))
    files = sorted(glob.glob(os.path.join(folder, "*.md")))
    out = []
    for f in files:
        if os.path.basename(f).startswith("08"):
            out.append(os.path.join(ROOT, "sdk", WORDS[lang]["sdk"]))
        out.append(f)
    return out


def to_html(path, number):
    text = open(path, encoding="utf-8").read()
    # links to other files of the repo: their text alone
    text = re.sub(r"\[([^\]]+)\]\((?!https?:)[^)]*\)", r"\1", text)
    # nested lists: 2 spaces a level here, 4 for python markdown
    text = re.sub(r"^((?:  )+)(?=[-*] |\d+\. )", lambda m: m.group(1) * 2, text, flags=re.M)
    if number is not None:                  # the SDK guide: chapter 7
        text = re.sub(r"^# (.*)$", rf"# {number}. \1", text, count=1, flags=re.M)
    return markdown.markdown(text, extensions=["tables", "fenced_code"])


marks = []                                  # (level, title, page)
heads = []                                  # the story's h1, h2 still to come


def note(pos):
    if pos.heading in (1, 2) and pos.open_close & 1 and heads:
        marks.append((pos.heading, heads.pop(0), pos.page + 1))


def headings(body):
    return [html.unescape(re.sub(r"<[^>]+>", "", t))
            for t in re.findall(r"<h[12][^>]*>(.*?)</h[12]>", body)]


def main():
    if len(sys.argv) not in (2, 3) or sys.argv[2:] and sys.argv[2] not in WORDS:
        sys.exit(__doc__.split("\n")[2])
    out = sys.argv[1]
    lang = sys.argv[2] if sys.argv[2:] else "el"
    w = WORDS[lang]
    files = chapters(lang)
    parts = []
    for f in files:
        name = os.path.basename(f)
        if name.startswith("00"):
            continue                        # the index: the contents page instead
        parts.append(to_html(f, 7 if name.startswith("README") else None))
    titles = [re.search(r"<h1>(.*?)</h1>", p).group(1) for p in parts]
    index = to_html(files[0], None)
    intro = re.sub(r"<h1>.*?</h1>", "", index.split("<h2>")[0], count=1)
    cover = ('<p class="title">V-OS</p>'
             f'<p class="subtitle">{w["subtitle"]}</p>'
             f'<p class="subtitle">{w["docs"]}</p>'
             f'<p class="small">{w["made"]}</p>')
    contents = (f'<h1>{w["contents"]}</h1>' + intro + "<ul>"
                + "".join(f"<li>{t}</li>" for t in titles) + "</ul>")
    pages = [cover, contents] + parts

    arch = fitz.Archive(FONTS)
    writer = fitz.DocumentWriter(out)
    pno = 0
    for k, body in enumerate(pages):
        story = fitz.Story(body, user_css=CSS, archive=arch)
        heads[:] = headings(body)
        more, start = True, pno
        while more:
            # a table row taller than a page never fits: MuPDF would add
            # empty pages for ever
            if pno - start > 60:
                sys.exit(f"{out}: part {k} ({re.sub('<.*?>', '', body[:80])}) "
                         "does not fit; a table row is taller than a page")
            dev = writer.begin_page(PAGE)
            more, _ = story.place(BODY)
            if k >= 2:
                story.element_positions(note, {"page": pno})
            story.draw(dev)
            writer.end_page()
            pno += 1
    writer.close()

    doc = fitz.open(out)
    font = fitz.Font(fontfile=os.path.join(FONTS, "NotoSans-Regular.ttf"))
    for i, page in enumerate(doc):
        if i == 0:
            continue
        label = f"V-OS — {i + 1}"
        width = font.text_length(label, fontsize=8)
        page.insert_text(((page.rect.width - width) / 2, page.rect.height - 30), label,
                         fontsize=8, fontname="noto", fontfile=os.path.join(FONTS, "NotoSans-Regular.ttf"),
                         color=(0.35, 0.38, 0.5))
    seen, toc = set(), [[1, w["contents"], 2]]
    for level, title, page in marks:
        if (level, title, page) not in seen:
            seen.add((level, title, page))
            toc.append([level, title, page])
    doc.set_toc(toc)
    doc.set_metadata({"title": w["title"], "subject": "Amstrad CPC 6128"})
    doc.save(out + ".tmp", garbage=3, deflate=True)
    doc.close()
    os.replace(out + ".tmp", out)
    print(f"{out}: {pno} pages")


if __name__ == "__main__":
    main()
