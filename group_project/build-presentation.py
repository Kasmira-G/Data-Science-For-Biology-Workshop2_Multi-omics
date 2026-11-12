"""Build an editable PowerPoint deck (03-presentation.pptx) for the Study B
group project. Every element is placed at an exact position, so nothing can
be silently clipped. Run:  python3 build-presentation.py
"""

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

# ---------------------------------------------------------------- palette ---
TEAL = RGBColor(0x0F, 0x76, 0x6E)
TEAL_LIGHT = RGBColor(0xE6, 0xF4, 0xF1)
CORAL = RGBColor(0xE2, 0x72, 0x5B)
DARK = RGBColor(0x2B, 0x2D, 0x42)
GRAY = RGBColor(0x6B, 0x72, 0x80)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
RED = RGBColor(0xC0, 0x39, 0x2B)

TITLE_FONT = "Georgia"
BODY_FONT = "Calibri"

SW, SH = 13.333, 7.5  # slide size, inches

prs = Presentation()
prs.slide_width = Inches(SW)
prs.slide_height = Inches(SH)
BLANK = prs.slide_layouts[6]


# ---------------------------------------------------------------- helpers ---
def add_slide():
    return prs.slides.add_slide(BLANK)


def add_box(slide, x, y, w, h, fill=None, line=None, rounded=False):
    shape = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE,
        Inches(x), Inches(y), Inches(w), Inches(h))
    if rounded:
        try:
            shape.adjustments[0] = 0.045
        except Exception:
            pass
    if fill is None:
        shape.fill.background()
    else:
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill
    if line is None:
        shape.line.fill.background()
    else:
        shape.line.color.rgb = line
        shape.line.width = Pt(1)
    shape.shadow.inherit = False
    return shape


def add_text(slide, x, y, w, h, paras, align=PP_ALIGN.LEFT):
    """paras: list of dicts {runs:[(text, size, bold, italic, color)], space_before, align}"""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = para.get("align", align)
        if para.get("space_before"):
            p.space_before = Pt(para["space_before"])
        if para.get("space_after"):
            p.space_after = Pt(para["space_after"])
        if para.get("line_spacing"):
            p.line_spacing = para["line_spacing"]
        for text, size, bold, italic, color in para["runs"]:
            r = p.add_run()
            r.text = text
            r.font.size = Pt(size)
            r.font.bold = bold
            r.font.italic = italic
            r.font.color.rgb = color
            r.font.name = BODY_FONT
    return tb


def R(text, size=15, bold=False, italic=False, color=DARK):
    return (text, size, bold, italic, color)


def add_title(slide, text):
    add_text(slide, 0.55, 0.28, 12.2, 0.8,
             [{"runs": [R(text, 30, bold=True, color=TEAL)]}])
    add_box(slide, 0.6, 1.05, 2.1, 0.05, fill=CORAL)


def add_bullets(slide, x, y, w, h, items, size=15):
    """items: list of (level, runs) — level 0 gets '•', level 1 gets '–'."""
    paras = []
    for level, runs in items:
        mark = "•  " if level == 0 else "     –  "
        bullet_runs = [R(mark, size, color=TEAL if level == 0 else GRAY, bold=True)]
        paras.append({"runs": bullet_runs + runs, "space_before": 8 if level == 0 else 3,
                      "line_spacing": 1.05})
    return add_text(slide, x, y, w, h, paras)


def add_picture(slide, path, x, y, w, aspect, caption=None):
    h = w / aspect
    slide.shapes.add_picture(path, Inches(x), Inches(y), Inches(w), Inches(h))
    if caption:
        add_text(slide, x, y + h + 0.06, w, 0.5,
                 [{"runs": [R(caption, 11, italic=True, color=GRAY)],
                   "line_spacing": 1.0}])
    return h


def add_notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


# ------------------------------------------------------------ slide 1: title
s = add_slide()
add_box(s, 0, 0, 0.5, SH, fill=TEAL)
add_box(s, 0, 0, 0.5, 2.1, fill=CORAL)
add_text(s, 1.1, 0.55, 11.5, 0.4,
         [{"runs": [R("DATA SCIENCE FOR BIOLOGY  ·  WORKSHOP 2  ·  GROUP PROJECT",
                      12, bold=True, color=GRAY)]}])
add_text(s, 1.1, 2.15, 11.0, 2.2, [
    {"runs": [R("Do contraceptive methods change the\nvaginal environment?", 38,
                bold=True, color=DARK)], "line_spacing": 1.05}])
add_text(s, 1.1, 4.35, 11.0, 0.6,
         [{"runs": [R("Study B — 93 samples  ·  pill / injectable / ring", 20,
                      bold=True, color=TEAL)]}])
add_text(s, 1.1, 6.45, 11.0, 0.5,
         [{"runs": [R("Group project · Multi-omics week · "
                      "microbiome + RNA-seq + cytokines", 13, color=GRAY)]}])
add_notes(s, "One-sentence take-home to open with: the methods barely differ; "
             "the community state is the stronger signal. The rest of the deck "
             "earns that sentence.")

# ------------------------------------------------- slide 2: background
s = add_slide()
add_title(s, "Background & question")

add_box(s, 0.6, 1.45, 6.0, 5.5, fill=TEAL_LIGHT, rounded=True)
add_text(s, 0.9, 1.7, 5.5, 0.5,
         [{"runs": [R("The setting", 18, bold=True, color=TEAL)]}])
add_bullets(s, 0.9, 2.25, 5.5, 4.5, [
    (0, [R("Hormonal contraception is used by millions of women, but its "
           "effect on the vaginal environment is not well mapped.", 15)]),
    (0, [R("The vaginal environment has three measurable layers:", 15)]),
    (1, [R("who is there", 15, bold=True), R(" — 220 bacterial species", 15)]),
    (1, [R("what the tissue is doing", 15, bold=True),
          R(" — ~14,000 human genes", 15)]),
    (1, [R("immune signalling", 15, bold=True), R(" — 15 cytokines", 15)]),
])

add_box(s, 7.0, 1.45, 5.75, 5.5, fill=None, line=CORAL, rounded=True)
add_text(s, 7.35, 1.7, 5.2, 0.5,
         [{"runs": [R("Our two questions", 18, bold=True, color=CORAL)]}])
add_bullets(s, 7.35, 2.25, 5.2, 4.5, [
    (0, [R("1.  ", 15, bold=True, color=CORAL),
          R("Do the three hormonal methods (pill, injectable, ring) produce "
            "different vaginal microbiomes or transcriptomes?", 15)]),
    (0, [R("2.  ", 15, bold=True, color=CORAL),
          R("Does ", 15),
          R("community type", 15, bold=True),
          R(" — Lactobacillus-dominant vs diverse — explain gene activity "
            "better than the method does?", 15)]),
])
add_notes(s, "One-sentence take-home to open with: the methods barely differ; "
             "the community state is the stronger signal.")

# ------------------------------------------------- slide 3: study design
s = add_slide()
add_title(s, "Study design")
add_bullets(s, 0.65, 1.45, 12.0, 4.0, [
    (0, [R("Cohort:  ", 16, bold=True),
          R("93 women, one sample each, cross-sectional.", 16)]),
    (0, [R("Three arms:  ", 16, bold=True),
          R("pill, injectable, ring — the ring acts ", 16),
          R("locally", 16, bold=True),
          R(" in the vagina; pill and injectable act ", 16),
          R("systemically", 16, bold=True), R(".", 16)]),
    (0, [R("Three data types per sample:  ", 16, bold=True),
          R("species counts (220 × 93), RNA-seq gene counts (14,226 × 93), "
            "cytokines (15 per sample).", 16)]),
    (0, [R("Design is clean:  ", 16, bold=True),
          R("sequencing batches balanced across arms (47 vs 46); BV and STI "
            "prevalence spread across arms — nothing is confounded with the "
            "method.", 16)]),
])
add_box(s, 0.6, 5.55, 12.1, 1.35, fill=TEAL_LIGHT, rounded=True)
add_text(s, 0.95, 5.75, 11.4, 1.0, [
    {"runs": [R("Key rule we follow:  ", 15, bold=True, color=TEAL),
               R("community type is defined ", 15),
               R("from the species table only", 15, bold=True),
               R(", then tested ", 15),
               R("on the gene table", 15, bold=True),
               R(" — never define a group from one table and test that "
                 "same table.", 15)]}])
add_notes(s, "If asked why one sample per woman: this is a cross-sectional "
             "comparison between methods, not a before/after trial like the "
             "probiotic Study A.")

# ------------------------------------------------- slide 4: QC
s = add_slide()
add_title(s, "Quality control — the gate before any test")

rows, cols = 8, 2
tbl_shape = s.shapes.add_table(rows, cols, Inches(0.6), Inches(1.45),
                               Inches(6.3), Inches(4.6))
tbl = tbl_shape.table
tbl.columns[0].width = Inches(4.5)
tbl.columns[1].width = Inches(1.8)

data = [
    ("Check", "Result"),
    ("Count columns match metadata rows", "PASS"),
    ("No duplicate / unmatched IDs", "PASS"),
    ("All species + genes annotated", "PASS"),
    ("bv label = Nugent bands", "PASS"),
    ("Depth: shallowest 5,247 reads", "PASS"),
    ("Batch vs arm: no confounding", "PASS"),
    ("Cytokines: B018, B029 all-NA", "FLAG"),
]
for i, (a, b) in enumerate(data):
    for j, txt in enumerate((a, b)):
        cell = tbl.cell(i, j)
        cell.text = txt
        p = cell.text_frame.paragraphs[0]
        r = p.runs[0]
        r.font.size = Pt(13)
        r.font.name = BODY_FONT
        if i == 0:
            r.font.bold = True
            r.font.color.rgb = WHITE
            cell.fill.solid()
            cell.fill.fore_color.rgb = TEAL
        else:
            if j == 1:
                r.font.bold = True
                r.font.color.rgb = TEAL if txt == "PASS" else RED
            if i % 2 == 0:
                cell.fill.solid()
                cell.fill.fore_color.rgb = RGBColor(0xF3, 0xF7, 0xF6)

img_h = add_picture(s, "01-qc_files/figure-html/depth-plot-1.png",
                    7.35, 1.55, 5.35, 1.4,
                    caption="Sequencing depth of every sample, both tables "
                            "(log scale). All samples clear the 1,000-read line.")
add_box(s, 7.35, 1.55 + img_h + 0.62, 5.35, 1.15, fill=TEAL_LIGHT, rounded=True)
add_text(s, 7.6, 1.55 + img_h + 0.78, 4.9, 0.9, [
    {"runs": [R("Carry-forward: ", 14, bold=True, color=TEAL),
               R("all 93 samples", 14, bold=True),
               R(" into microbiome & RNA-seq; ", 14),
               R("91 into cytokine analyses", 14, bold=True),
               R(" (B018, B029 dropped there only).", 14)]}])
add_text(s, 0.6, 6.6, 6.3, 0.4,
         [{"runs": [R("Full audit trail with spot-checks: 01-qc-report.html",
                      11, italic=True, color=GRAY)]}])
add_notes(s, "Why the depth plot matters: a shallow sample behaves oddly in "
             "every downstream method. Verify the shallowest sample with "
             "min(colSums(d$species)) = 5,247 in 01-qc.qmd.\n\n"
             "Why 'cytokine analyses only' for B018/B029: they are missing "
             "ALL 15 values (failed assay / lost tube), but their count tables "
             "are fine — dropping them everywhere would waste two good "
             "sequencing samples.")

# ------------------------------------------------- slide 5: methods
s = add_slide()
add_title(s, "Methods — and why we chose them")
add_bullets(s, 0.65, 1.45, 12.1, 5.6, [
    (0, [R("Community type:  ", 16, bold=True),
          R("fraction of reads from Lactobacillus ≥ 50% → lacto-dominant "
            "(48), else diverse (45). Both types occur in all three arms, so "
            "the two groupings are not copies of each other.", 15)]),
    (0, [R("Overall differences:  ", 16, bold=True),
          R("ordination (PCoA) + PERMANOVA (999 permutations, "
            "by = \"margin\").", 15)]),
    (1, [R("Species: ", 15), R("Bray–Curtis", 15, bold=True), R(" distance", 15)]),
    (1, [R("Genes: ", 15), R("CLR + Euclidean", 15, bold=True),
          R(" — raw gene counts would let a few very highly expressed genes "
            "dominate Bray–Curtis", 15)]),
    (0, [R("Per-gene differences:  ", 16, bold=True),
          R("DESeq2 on raw counts", 15, bold=True),
          R(" (never CPM or logged — it normalises itself), design "
            "~ rnaseq_batch + arm (or + community), genes kept if ≥ 10 counts "
            "in ≥ 24 samples, FDR 0.05 across ~14,000 tests.", 15)]),
    (0, [R("BV status as a yardstick  ", 16, bold=True),
          R("— a known biological effect, so the method effect has a sense "
            "of scale.", 15)]),
])
add_notes(s, "Choices to defend if asked:\n\n"
             "Why batch in the design? QC showed it is balanced across arms, "
             "so it cannot fake a method effect — but only if it is in the "
             "model.\n\n"
             "Why define community on species only? Testing a group on the "
             "table that defined it is circular; it guarantees a 'significant' "
             "result.\n\n"
             "Why FDR? ~14,000 genes tested at once — 5% of raw p-values "
             "would be false positives by chance alone (~700 genes!).")

# ------------------------------------------------- slide 6: results 1
s = add_slide()
add_title(s, "Results 1 — the methods barely differ")
y_img = 1.45
h1 = add_picture(s, "02-contraceptive_effect_files/figure-html/species-ord-1.png",
                 0.6, y_img, 5.55, 1.56,
                 caption="Species composition (Bray–Curtis PCoA) — points overlap.")
add_picture(s, "02-contraceptive_effect_files/figure-html/gene-ord-arm-1.png",
            7.15, y_img, 5.55, 1.56,
            caption="Gene activity (CLR + Euclidean PCoA) — points overlap.")

y_box = y_img + h1 + 0.7
add_box(s, 0.6, y_box, 12.1, 1.7, fill=TEAL_LIGHT, rounded=True)
add_bullets(s, 0.95, y_box + 0.15, 11.5, 1.5, [
    (0, [R("Species PERMANOVA:  ", 14, bold=True),
          R("method R² ~3%, p ≈ 0.08 — vs ", 14),
          R("~22% for BV", 14, bold=True), R(" (yardstick).", 14)]),
    (0, [R("Gene PERMANOVA:  ", 14, bold=True),
          R("method R² ~2.7%, not significant.", 14)]),
    (0, [R("DESeq2 pairwise (13,713 genes):  ", 14, bold=True),
          R("injectable vs pill ", 14), R("10", 14, bold=True),
          R(" FDR genes; ring contrasts ≈ ", 14),
          R("100–140", 14, bold=True), R(" each.", 14)]),
])
add_notes(s, "How to read this: the plots show overlap, and the numbers agree "
             "— method never explains more than ~3% of variation. The one "
             "structure worth chasing is ring vs the two systemic methods; "
             "injectable and pill are nearly indistinguishable. The yardstick "
             "matters: BV explains ~22% of species composition, so a real "
             "biological effect in this data looks like 22%, not 3%.\n\n"
             "Spot-check: results(dds_arm, contrast = c(\"arm\", "
             "\"injectable\", \"pill\")), sum(padj < 0.05, na.rm = TRUE) "
             "should be 10.")

# ------------------------------------------------- slide 7: results 2
s = add_slide()
add_title(s, "Results 2 — community type leaves a gene signature")
y_img = 1.45
h1 = add_picture(s, "02-contraceptive_effect_files/figure-html/gene-ord-com-1.png",
                 0.6, y_img, 7.1, 2.0,
                 caption="Ordination coloured two ways: community type (left "
                         "panel) separates more than method (right panel).")
add_picture(s, "02-contraceptive_effect_files/figure-html/volcano-padj-1.png",
            8.15, y_img, 4.55, 1.4,
            caption="Volcano plot, lacto-dominant vs diverse — y-axis = adjusted p "
                    "(FDR). Dots above the line are exactly the 310 FDR genes.")

y_box = y_img + h1 + 0.75
add_box(s, 0.6, y_box, 12.1, 1.6, fill=TEAL_LIGHT, rounded=True)
add_bullets(s, 0.95, y_box + 0.15, 11.5, 1.35, [
    (0, [R("Head-to-head on genes:  ", 14, bold=True),
          R("PERMANOVA says method ~2.6% vs community ~1.5% (both ns) — but "
            "DESeq2 says community ", 14),
          R("310", 14, bold=True), R(" FDR genes vs method ", 14),
          R("136", 14, bold=True), R(".", 14)]),
    (0, [R("The two lenses disagree, and that is the finding:  ", 14, bold=True),
          R("community type is the stronger target for a gene list, even "
            "though it explains little pooled variation.", 14)]),
])
add_notes(s, "Spot-check: rerun sum(genes_by_community$padj < 0.05, "
             "na.rm = TRUE) — it should be 310. The labelled top-10 genes in "
             "the volcano should all sit above the dashed FDR line.\n\n"
             "This volcano plots -log10(adjusted p): a dot above the line is "
             "exactly a gene passing FDR 0.05. Heights bunch into steps "
             "because the correction gives many genes the same adjusted "
             "value. The raw-p version (fine detail, near-misses visible) is "
             "in the analysis report.")

# ------------------------------------------------- slide 8: choices
s = add_slide()
add_title(s, "Choices we made")
choices = [
    ("Community type defined from the species table only; tested on genes only.",
     "Alternative not chosen: the circular test."),
    ("A simple two-type split at 50% Lactobacillus.",
     "Alternative not chosen: a three-way L. crispatus / L. iners / "
     "Gardnerella split — it explained no more of the gene ordination "
     "(R² 2.4% vs 1.5%) while being harder to explain."),
    ("Bray–Curtis for species, CLR + Euclidean for genes.",
     "Alternative not chosen: Bray–Curtis on raw gene counts — dominated by "
     "library size."),
    ("Batch included in every DESeq2 design; no samples dropped from the "
     "count tables.",
     "Alternative not chosen: dropping B018/B029 everywhere — that would "
     "waste two good sequencing samples."),
    ("BV status as a yardstick; by = \"margin\" PERMANOVA.",
     "Alternative not chosen: by = \"terms\", where the first term absorbs "
     "more credit."),
]
paras = []
for choice, alt in choices:
    paras.append({"runs": [R("•  ", 15, bold=True, color=TEAL),
                            R(choice, 15, bold=True)],
                  "space_before": 9, "line_spacing": 1.05})
    paras.append({"runs": [R("        " + alt, 12.5, italic=True, color=GRAY)],
                  "line_spacing": 1.0})
add_text(s, 0.65, 1.45, 12.1, 5.6, paras)
add_notes(s, "Every choice here is documented with its rejected alternative "
             "in the two reports: 01-qc-report.html and "
             "02-contraceptive-analysis.html.")

prs.save("03-presentation.pptx")
print("Saved 03-presentation.pptx with", len(prs.slides.slides if hasattr(prs.slides,'slides') else prs.slides._sldIdLst), "slides")
