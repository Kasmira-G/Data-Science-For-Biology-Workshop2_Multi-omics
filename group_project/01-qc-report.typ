// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)
        show figure.where(kind: kind): set figure(outlined: false)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  lof: false,
  lof-title: none,
  lot: false,
  lot-title: none,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if lof {
    block(above: 0em, below: 2em)[
    #outline(title: lof-title, target: figure.where(kind: "quarto-float-fig"));
    ]
  }

  if lot {
    block(above: 0em, below: 2em)[
    #outline(title: lot-title, target: figure.where(kind: "quarto-float-tbl"));
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 2cm,y: 2.2cm,),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [Quality control report --- Study B],
  subtitle: [Contraception cohort: 93 samples, three arms (pill, injectable, ring)],
  fontsize: 10pt,
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= What is this document?
<what-is-this-document>
Before we ran any statistical test on Study B (the contraception cohort), we checked that the data were sound. This report walks through those checks one by one, in plain words, with the exact code used so anyone can rerun or audit them.

#strong[Nothing in this report is a result.] It is the pass/fail gate that the rest of the analysis stands on. Each check ends with a #strong[Spot-check] --- a number or table you can produce yourself in a minute to confirm we did it right.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(tidyverse)");],
[#FunctionTok("library");#NormalTok("(here)");],
[],
[#CommentTok("# The workshop helper: reads all six files and returns them in one list.");],
[#FunctionTok("source");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"R/count_tables.R\"");#NormalTok("))");],
[#NormalTok("d ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_counts");#NormalTok("(");#StringTok("\"group_b\"");#NormalTok(")");],));
]
#NormalTok("read_counts()"); gives us #NormalTok("d$metadata");, #NormalTok("d$species"); (220 species x 93 samples), #NormalTok("d$genes"); (14,226 genes x 93 samples), #NormalTok("d$cytokines");, plus the two annotation tables. Both count tables are #strong[features in rows, samples in columns].

= 1. Do the six files agree with each other?
<do-the-six-files-agree-with-each-other>
#strong[In plain words:] the count tables store one column of numbers per sample, and the metadata table stores one row of labels per sample. If those two lists are not in the #emph[same order], every later test silently matches sample 1's counts with sample 7's label. DESeq2 and friends will not warn about this --- they will just be wrong. So we compare the column order of both raw count tables against the metadata row order, and check for duplicate sample IDs.

#block[
#Skylighting(([#CommentTok("# Read only the header row of each raw count table (fast, no data parsed).");],
[#NormalTok("species_header ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("names");#NormalTok("(");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("path, ");#StringTok("\"02_microbiome_counts.csv\"");#NormalTok("), ");#AttributeTok("n_max =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("show_col_types =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok("))[");#SpecialCharTok("-");#DecValTok("1");#NormalTok("]");],
[#NormalTok("genes_header   ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("names");#NormalTok("(");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("path, ");#StringTok("\"04_rnaseq_counts.csv.gz\"");#NormalTok("),  ");#AttributeTok("n_max =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("show_col_types =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok("))[");#SpecialCharTok("-");#DecValTok("1");#NormalTok("]");],
[],
[#FunctionTok("tibble");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("check =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"microbiome columns == metadata rows (same order)\"");#NormalTok(",");],
[#NormalTok("            ");#StringTok("\"rnaseq columns == metadata rows (same order)\"");#NormalTok(",");],
[#NormalTok("            ");#StringTok("\"no duplicated sample_ids\"");#NormalTok(",");],
[#NormalTok("            ");#StringTok("\"cytokine rows == metadata rows (same order)\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("result =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("identical");#NormalTok("(species_header, d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("sample_id),");],
[#NormalTok("    ");#FunctionTok("identical");#NormalTok("(genes_header,   d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("sample_id),");],
[#NormalTok("    ");#SpecialCharTok("!");#FunctionTok("any");#NormalTok("(");#FunctionTok("duplicated");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("sample_id)),");],
[#NormalTok("    ");#FunctionTok("identical");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("cytokines");#SpecialCharTok("$");#NormalTok("sample_id, d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("sample_id)");],
[#NormalTok("  )");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 4 × 2");],
[#NormalTok("  check                                            result");],
[#NormalTok("  <chr>                                            <lgl> ");],
[#NormalTok("1 microbiome columns == metadata rows (same order) TRUE  ");],
[#NormalTok("2 rnaseq columns == metadata rows (same order)     TRUE  ");],
[#NormalTok("3 no duplicated sample_ids                         TRUE  ");],
[#NormalTok("4 cytokine rows == metadata rows (same order)      TRUE  ");],));
]
]
Second, every feature in a count table should be described by its annotation file. If a species or gene has no annotation row, later plots and enrichment tests will drop it #emph[silently] --- we would never know a feature was missing.

#block[
#Skylighting(([#FunctionTok("tibble");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("check =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"all 220 species have a taxonomy row\"");#NormalTok(",");],
[#NormalTok("            ");#StringTok("\"all 14,226 genes have an annotation row\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("result =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("all");#NormalTok("(");#FunctionTok("rownames");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("species) ");#SpecialCharTok("%in%");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("taxonomy");#SpecialCharTok("$");#NormalTok("taxon),");],
[#NormalTok("    ");#FunctionTok("all");#NormalTok("(");#FunctionTok("rownames");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("genes) ");#SpecialCharTok("%in%");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("gene_info");#SpecialCharTok("$");#NormalTok("ensembl_gene_id)");],
[#NormalTok("  )");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 2 × 2");],
[#NormalTok("  check                                   result");],
[#NormalTok("  <chr>                                   <lgl> ");],
[#NormalTok("1 all 220 species have a taxonomy row     TRUE  ");],
[#NormalTok("2 all 14,226 genes have an annotation row TRUE  ");],));
]
]
#strong[Spot-check:] all four rows of the first table and both rows of the second should say #NormalTok("TRUE");.

= 2. Is the metadata sane?
<is-the-metadata-sane>
#strong[In plain words:] the sample sheet is where typing mistakes hide --- missing values, labels we did not expect, or numbers outside plausible ranges. Any of these would bite us during modelling, so we look before we model.

#block[
#Skylighting(([#FunctionTok("cat");#NormalTok("(");#StringTok("\"Missing values in metadata:\"");#NormalTok(", ");#FunctionTok("sum");#NormalTok("(");#FunctionTok("is.na");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("metadata)), ");#StringTok("\"");#SpecialCharTok("\\n");#StringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Missing values in metadata: 0 ");],));
]
#Skylighting(([#FunctionTok("cat");#NormalTok("(");#StringTok("\"Missing values per column:");#SpecialCharTok("\\n");#StringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Missing values per column:");],));
]
#Skylighting(([#FunctionTok("colSums");#NormalTok("(");#FunctionTok("is.na");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("metadata))");],));
#block[
#Skylighting(([#NormalTok("     sample_id participant_id            arm             bv         nugent ");],
[#NormalTok("             0              0              0              0              0 ");],
[#NormalTok("            ph        any_sti   rnaseq_batch ");],
[#NormalTok("             0              0              0 ");],));
]
]
#block[
#Skylighting(([#CommentTok("# Counts per category — small arms or one-sample batches would be a problem.");],
[#NormalTok("d");#SpecialCharTok("$");#NormalTok("metadata ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("count");#NormalTok("(arm) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("bind_rows");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("metadata ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("count");#NormalTok("(rnaseq_batch) ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("rename");#NormalTok("(");#AttributeTok("arm =");#NormalTok(" rnaseq_batch)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("arm =");#NormalTok(" ");#FunctionTok("paste0");#NormalTok("(");#StringTok("\"arm/rnaseq_batch: \"");#NormalTok(", arm))");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 5 × 2");],
[#NormalTok("  arm                              n");],
[#NormalTok("  <chr>                        <int>");],
[#NormalTok("1 arm/rnaseq_batch: injectable    39");],
[#NormalTok("2 arm/rnaseq_batch: pill          28");],
[#NormalTok("3 arm/rnaseq_batch: ring          26");],
[#NormalTok("4 arm/rnaseq_batch: B1            47");],
[#NormalTok("5 arm/rnaseq_batch: B2            46");],));
]
]
#block[
#Skylighting(([#CommentTok("# Ranges of the two numeric clinical variables.");],
[#NormalTok("d");#SpecialCharTok("$");#NormalTok("metadata ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("  ");#FunctionTok("across");#NormalTok("(");#FunctionTok("c");#NormalTok("(nugent, ph), ");#FunctionTok("list");#NormalTok("(");#AttributeTok("min =");#NormalTok(" min, ");#AttributeTok("max =");#NormalTok(" max)),");],
[#NormalTok("  ");#AttributeTok("n =");#NormalTok(" ");#FunctionTok("n");#NormalTok("()");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 5");],
[#NormalTok("  nugent_min nugent_max ph_min ph_max     n");],
[#NormalTok("       <dbl>      <dbl>  <dbl>  <dbl> <int>");],
[#NormalTok("1          0         10    3.6    6.1    93");],));
]
]
Nugent scores run 0--10 and vaginal pH in these data runs \~3.6--6.1; both are inside those bounds, so nothing is implausible.

One internal consistency check worth doing: the #NormalTok("bv"); column should agree with the Nugent score (0--3 negative, 4--6 intermediate, 7--10 positive). If the two disagreed, one of them would be wrong and we would not know which.

#block[
#Skylighting(([#NormalTok("d");#SpecialCharTok("$");#NormalTok("metadata ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("nugent_band =");#NormalTok(" ");#FunctionTok("cut");#NormalTok("(nugent, ");#FunctionTok("c");#NormalTok("(");#SpecialCharTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("10");#NormalTok("),");],
[#NormalTok("                           ");#AttributeTok("labels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"negative\"");#NormalTok(", ");#StringTok("\"intermediate\"");#NormalTok(", ");#StringTok("\"positive\"");#NormalTok("))) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("count");#NormalTok("(nugent_band, bv)   ");#CommentTok("# counts should sit on the diagonal");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 3 × 3");],
[#NormalTok("  nugent_band  bv               n");],
[#NormalTok("  <fct>        <chr>        <int>");],
[#NormalTok("1 negative     negative        51");],
[#NormalTok("2 intermediate intermediate     3");],
[#NormalTok("3 positive     positive        39");],));
]
]
#strong[Spot-check:] every row in this little table should have #NormalTok("nugent_band"); matching #NormalTok("bv");. Also check #NormalTok("sample_id == participant_id"); if you want to confirm each woman was sampled once (in Study B, she was: 93 IDs, all identical).

= 3. How deep are the count tables?
<how-deep-are-the-count-tables>
#strong[In plain words:] "depth" is the total number of reads sequenced per sample. A shallow sample behaves oddly in every downstream method --- its relative abundances are noisy and its compositional distortion is worse. We plot every sample's total on a log scale (so the much larger RNA-seq numbers fit on the same plot) and draw a line at 1,000 reads below which we would worry.

#block[
#Skylighting(([#NormalTok("depth ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("tibble");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("sample_id =");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("sample_id,");],
[#NormalTok("  ");#AttributeTok("arm       =");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("arm,");],
[#NormalTok("  ");#AttributeTok("microbiome_reads =");#NormalTok(" ");#FunctionTok("colSums");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("species),");],
[#NormalTok("  ");#AttributeTok("rnaseq_reads     =");#NormalTok(" ");#FunctionTok("colSums");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("genes)");],
[#NormalTok(")");],
[#CommentTok("# (all 93 rows are in the HTML version; here just a preview)");],
[#FunctionTok("head");#NormalTok("(depth, ");#DecValTok("6");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 4");],
[#NormalTok("  sample_id arm        microbiome_reads rnaseq_reads");],
[#NormalTok("  <chr>     <chr>                 <dbl>        <dbl>");],
[#NormalTok("1 B001      pill                  54122     14270990");],
[#NormalTok("2 B002      injectable            23843     12372791");],
[#NormalTok("3 B003      injectable            14057      9189179");],
[#NormalTok("4 B004      ring                  44211     15501829");],
[#NormalTok("5 B005      pill                  27343     14203870");],
[#NormalTok("6 B006      ring                   5247     12727010");],));
]
]
#Skylighting(([#CommentTok("# Overlay both tables on a log scale so the very different magnitudes share a plot.");],
[#NormalTok("depth ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");#FunctionTok("c");#NormalTok("(microbiome_reads, rnaseq_reads),");],
[#NormalTok("               ");#AttributeTok("names_to =");#NormalTok(" ");#StringTok("\"table\"");#NormalTok(", ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"reads\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(reads, ");#AttributeTok("fill =");#NormalTok(" table)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_histogram");#NormalTok("(");#AttributeTok("bins =");#NormalTok(" ");#DecValTok("30");#NormalTok(", ");#AttributeTok("position =");#NormalTok(" ");#StringTok("\"identity\"");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_vline");#NormalTok("(");#AttributeTok("xintercept =");#NormalTok(" ");#DecValTok("1000");#NormalTok(", ");#AttributeTok("linetype =");#NormalTok(" ");#StringTok("\"dashed\"");#NormalTok(") ");#SpecialCharTok("+");#NormalTok("   ");#CommentTok("# our low-depth line");],
[#NormalTok("  ");#FunctionTok("scale_x_log10");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Per-sample totals, Study B\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"reads per sample (log scale)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"samples\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#box(image("01-qc-report_files/figure-typst/depth-plot, fig-width- 6.5, fig-height- 3.2-1.svg"))

#block[
#Skylighting(([#NormalTok("depth ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("arrange");#NormalTok("(microbiome_reads) ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("slice");#NormalTok("(");#DecValTok("1");#SpecialCharTok(":");#DecValTok("3");#NormalTok(")   ");#CommentTok("# shallowest microbiome samples");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 3 × 4");],
[#NormalTok("  sample_id arm        microbiome_reads rnaseq_reads");],
[#NormalTok("  <chr>     <chr>                 <dbl>        <dbl>");],
[#NormalTok("1 B006      ring                   5247     12727010");],
[#NormalTok("2 B083      ring                  10756     11185837");],
[#NormalTok("3 B065      injectable            11570     18130140");],));
]
#Skylighting(([#NormalTok("depth ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("arrange");#NormalTok("(rnaseq_reads)     ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("slice");#NormalTok("(");#DecValTok("1");#SpecialCharTok(":");#DecValTok("3");#NormalTok(")   ");#CommentTok("# shallowest rnaseq samples");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 3 × 4");],
[#NormalTok("  sample_id arm        microbiome_reads rnaseq_reads");],
[#NormalTok("  <chr>     <chr>                 <dbl>        <dbl>");],
[#NormalTok("1 B042      injectable            34734      5855848");],
[#NormalTok("2 B071      ring                  31896      6638571");],
[#NormalTok("3 B008      injectable            20556      7453706");],));
]
]
The shallowest microbiome sample has 5,247 reads and the shallowest RNA-seq library about 5,855,848 --- both well past our low-depth line. #strong[No sample needs dropping for depth.]

#strong[Spot-check:] rerun #NormalTok("min(colSums(d$species))"); yourself --- it should be 5,247, not something like 500.

= 4. How sparse are they?
<how-sparse-are-they>
#strong[In plain words:] both tables are #emph[compositional] --- each sample's column sums to a fixed total of what was sequenced, so a species going up in one sample means others #emph[appear] to go down. How many zeros a table carries decides which statistical methods are safe on it. This is why the two tables will need different transforms later. Neither number below is a quality problem; it is just what the tables #emph[are].

#block[
#Skylighting(([#FunctionTok("tibble");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("table =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"microbiome\"");#NormalTok(", ");#StringTok("\"rnaseq\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("zero_fraction =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#FunctionTok("mean");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("species ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok("), ");#FunctionTok("mean");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("genes ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok("))");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 2 × 2");],
[#NormalTok("  table      zero_fraction");],
[#NormalTok("  <chr>              <dbl>");],
[#NormalTok("1 microbiome        0.884 ");],
[#NormalTok("2 rnaseq            0.0325");],));
]
]
88% zeros in the microbiome table is normal for species-level counts; 3% in the RNA-seq table is normal for a shallow-ish whole-transcriptome assay.

= 5. Is the design balanced?
<is-the-design-balanced>
#strong[In plain words:] if one sequencing batch had processed (say) only the pill samples, then any difference we found between arms could really be a difference between #emph[batches] --- and no statistical test could tell those apart. So we cross-tabulate batch against arm, and check that BV and STI prevalence are spread reasonably across arms too.

#block[
#Skylighting(([#FunctionTok("table");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("rnaseq_batch, d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("arm)");],));
#block[
#Skylighting(([#NormalTok("    ");],
[#NormalTok("     injectable pill ring");],
[#NormalTok("  B1         20   14   13");],
[#NormalTok("  B2         19   14   13");],));
]
]
#block[
#Skylighting(([#FunctionTok("table");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("arm, d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("bv)");],));
#block[
#Skylighting(([#NormalTok("            ");],
[#NormalTok("             intermediate negative positive");],
[#NormalTok("  injectable            0       20       19");],
[#NormalTok("  pill                  2       16       10");],
[#NormalTok("  ring                  1       15       10");],));
]
#Skylighting(([#FunctionTok("table");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("arm, d");#SpecialCharTok("$");#NormalTok("metadata");#SpecialCharTok("$");#NormalTok("any_sti)");],));
#block[
#Skylighting(([#NormalTok("            ");],
[#NormalTok("              0  1");],
[#NormalTok("  injectable 20 19");],
[#NormalTok("  pill       16 12");],
[#NormalTok("  ring        9 17");],));
]
]
Both batches contain a similar mix of all three arms, and BV/STI prevalence is comparable across arms. Nothing is confounded with #NormalTok("arm"); at first sight.

#strong[Spot-check:] add up one row of the batch x arm table (B1: 20 + 14 + 13 = 47) and one column (pill: 14 + 14 = 28). The two should agree with the marginal totals.

= 6. Are the cytokines complete?
<are-the-cytokines-complete>
#strong[In plain words:] the cytokine table is measured by a separate assay, so it can fail separately from the sequencing. Here we count missing values per sample to see whether any sample is missing a few values (scattered bad measurements) or all of them (a failed assay or a lost tube --- a very different problem).

#block[
#Skylighting(([#CommentTok("# Which samples have missing values, and how many?");],
[#NormalTok("cy ");#OtherTok("<-");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("cytokines");],
[#NormalTok("missing_per_sample ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rowSums");#NormalTok("(");#FunctionTok("is.na");#NormalTok("(cy[, ");#SpecialCharTok("-");#DecValTok("1");#NormalTok("]))");],
[#FunctionTok("tibble");#NormalTok("(");#AttributeTok("sample_id =");#NormalTok(" cy");#SpecialCharTok("$");#NormalTok("sample_id[missing_per_sample ");#SpecialCharTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok("],");],
[#NormalTok("       ");#AttributeTok("n_missing =");#NormalTok(" missing_per_sample[missing_per_sample ");#SpecialCharTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok("])");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 2 × 2");],
[#NormalTok("  sample_id n_missing");],
[#NormalTok("  <chr>         <dbl>");],
[#NormalTok("1 B018             15");],
[#NormalTok("2 B029             15");],));
]
]
Two samples, #NormalTok("B018"); and #NormalTok("B029");, are missing #strong[all 15] cytokine values. That looks like a failed assay or a lost tube, not a scattered bad measurement, so the sensible move is to drop those two samples from any #emph[cytokine] analysis --- and only from it. Their count tables are fine, so they stay in the microbiome and RNA-seq analyses.

#strong[Spot-check:] #NormalTok("cy[missing_per_sample > 0, 1:4]"); should show two rows of #NormalTok("NA");.

= Verdict
<verdict>
Study B is in good shape:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Check], [Result],),
  table.hline(),
  [Column order matches metadata, both tables], [PASS],
  [No duplicate / unmatched samples], [PASS],
  [All features annotated], [PASS],
  [No missing metadata], [PASS],
  [#NormalTok("bv"); labels match Nugent bands], [PASS],
  [Depth: no sample near the low-depth line], [PASS],
  [Batch not confounded with arm], [PASS],
  [Cytokines: 2 samples (B018, B029) all-NA], [flag: drop them in cytokine analyses only],
)
#strong[Carry forward:] all 93 samples into the microbiome and RNA-seq analyses; 91 into anything that uses cytokines. Raw counts (not CPM, not logged) into DESeq2 when we get there.

= How to check this yourself
<how-to-check-this-yourself>
Open #NormalTok("01-qc.qmd"); in the #NormalTok("group_project/"); folder --- it is the working version of this report with the same code. Each #strong[Spot-check] above names the one number or table that would catch an error: the most useful single one is #NormalTok("min(colSums(d$species))"); = 5,247, and the batch x arm cross-table whose rows and columns must add up to the same margins.

= Choices made
<choices-made>
- Loaded all six files through the workshop helper #NormalTok("read_counts(\"group_b\")"); instead of six separate #NormalTok("read_csv()"); calls. #emph[Alternative not chosen:] read and join the files by hand.
- Checked the #strong[raw] column order against the metadata rows before trusting the helper's reordering. #emph[Alternative not chosen:] assume the helper fixed it and skip the check.
- Set the low-depth line for the microbiome at 1,000 reads total. #emph[Alternative not chosen:] 10,000 reads, which would have flagged B006 (5,247) for review.
- Kept the Nugent bands 0--3 / 4--6 / 7--10 as the definition of #NormalTok("bv"); and verified the label column against them. #emph[Alternative not chosen:] take the #NormalTok("bv"); label on trust.
- Decided to drop B018 and B029 from cytokine analyses only, because they are missing all 15 values. #emph[Alternative not chosen:] drop them from every table, which would cost two perfectly good microbiome/RNA-seq samples.
- Assessed depth and sparsity on raw counts, with no transform. #emph[Alternative not chosen:] QC on relative abundances, which hides how deep a sample is.
- Checked batch/arm confounding with a plain cross-table. #emph[Alternative not chosen:] leave the question until the modelling step and discover it there.
- No samples were filtered out of the count tables at this stage. #emph[Alternative not chosen:] pre-filter to, say, 90% of the samples and analyse the rest.
