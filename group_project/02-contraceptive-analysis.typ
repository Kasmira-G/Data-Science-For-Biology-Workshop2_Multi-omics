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
  margin: (x: 2cm,y: 2cm,),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [Analysis report --- Study B],
  subtitle: [Do contraceptive methods differ, and does community type explain more than the method?],
  fontsize: 10pt,
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= What is this document?
<what-is-this-document>
Study B is the contraception cohort: 93 samples, three hormonal methods (#NormalTok("pill");, #NormalTok("injectable");, #NormalTok("ring");). The #link("01-qc-report.pdf")[quality control report] passed every check, so all 93 samples go into the analyses here.

This report answers two questions and shows the code behind every number, so anyone can rerun or audit them:

- #strong[Main question: do the three methods differ in their effect on the vaginal environment?] We look at both tables --- the 220 bacterial species and the \~14,000 human genes. "Differ" can mean two things: do the samples #emph[look] different overall (an ordination + PERMANOVA question), and do specific genes or species #emph[measure] different (a DESeq2 question).
- #strong[Sub-question: does community type explain more of the gene activity than the method does?] People in this cohort cluster into two vaginal community types --- those dominated by #emph[Lactobacillus] and those with a more diverse community. We define that type #strong[from the species table only] (the workshop rule: never define a group from one count table and then test that same table), and then test it #strong[on the gene table], next to the method.

Each section opens with an #emph["In plain words:"] paragraph, and the report ends with the list of choices made and rejected alternatives.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(tidyverse)");],
[#FunctionTok("library");#NormalTok("(here)");],
[#FunctionTok("library");#NormalTok("(DESeq2)");],
[#FunctionTok("library");#NormalTok("(microViz)");],
[#FunctionTok("library");#NormalTok("(phyloseq)");],
[],
[#FunctionTok("source");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"R/count_tables.R\"");#NormalTok("))");],
[#NormalTok("d ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_counts");#NormalTok("(");#StringTok("\"group_b\"");#NormalTok(")");],));
]
= Step 0: define community type from the species table
<step-0-define-community-type-from-the-species-table>
#strong[In plain words:] we compute, for every sample, the fraction of its reads that belong to the genus #emph[Lactobacillus], then split at 0.5. At least half Lactobacillus → #NormalTok("lacto-dominant");\; anything else → #NormalTok("diverse");. This is the same recipe as notebook 02, and it uses #strong[only the species table] --- the gene table is not touched until Step 2, where this group is tested on it.

#block[
#Skylighting(([#NormalTok("lacto_taxa ");#OtherTok("<-");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("taxonomy");#SpecialCharTok("$");#NormalTok("taxon[d");#SpecialCharTok("$");#NormalTok("taxonomy");#SpecialCharTok("$");#NormalTok("Genus ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"Lactobacillus\"");#NormalTok("]");],
[#NormalTok("lacto_frac ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("colSums");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("species[lacto_taxa, , ");#AttributeTok("drop =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok("]) ");#SpecialCharTok("/");#NormalTok(" ");#FunctionTok("colSums");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("species)");],
[],
[#NormalTok("meta ");#OtherTok("<-");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("metadata ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("lacto_fraction =");#NormalTok(" lacto_frac[sample_id],");],
[#NormalTok("    ");#AttributeTok("community =");#NormalTok(" ");#FunctionTok("cut");#NormalTok("(lacto_fraction, ");#FunctionTok("c");#NormalTok("(");#SpecialCharTok("-");#FloatTok("0.01");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("1.01");#NormalTok("),");],
[#NormalTok("                    ");#AttributeTok("labels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"diverse\"");#NormalTok(", ");#StringTok("\"lacto-dominant\"");#NormalTok("))");],
[#NormalTok("  )");],));
]
#block[
#Skylighting(([#CommentTok("# Do the community types spread across the three arms, or pile into one?");],
[#FunctionTok("table");#NormalTok("(meta");#SpecialCharTok("$");#NormalTok("community, meta");#SpecialCharTok("$");#NormalTok("arm)");],));
#block[
#Skylighting(([#NormalTok("                ");],
[#NormalTok("                 injectable pill ring");],
[#NormalTok("  diverse                20   11   14");],
[#NormalTok("  lacto-dominant         19   17   12");],));
]
]
The split is roughly even (45 #NormalTok("diverse");, 48 #NormalTok("lacto-dominant");) and both community types occur in all three arms, so community is not just a hidden copy of the method. Good enough to compare the two.

= Question 1: do the three methods differ?
<question-1-do-the-three-methods-differ>
== 1a. Do the species profiles differ by method?
<a.-do-the-species-profiles-differ-by-method>
#strong[In plain words:] an ordination plot is a 2-D map of "who is similar to whom": samples that plot close together have similar species compositions. Bray-Curtis is the distance measure used here --- it compares which species are present and in what relative amounts. The PERMANOVA below then puts a number on what you see: it shuffles the method labels 999 times and asks how often a shuffled labelling would produce an effect this big (that frequency is the p-value), and R² says what fraction of the total variation the method explains.

#Skylighting(([#NormalTok("ps_species ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as_counts");#NormalTok("(");#AttributeTok("data =");#NormalTok(" d, ");#AttributeTok("table =");#NormalTok(" ");#StringTok("\"microbiome\"");#NormalTok(")");],
[#NormalTok("sd0 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as");#NormalTok("(");#FunctionTok("sample_data");#NormalTok("(ps_species), ");#StringTok("\"data.frame\"");#NormalTok(")");],
[#NormalTok("sd1 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame");#NormalTok("(meta[");#FunctionTok("match");#NormalTok("(");#FunctionTok("rownames");#NormalTok("(sd0), meta");#SpecialCharTok("$");#NormalTok("sample_id), ])");],
[#FunctionTok("rownames");#NormalTok("(sd1) ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(sd0)");],
[#FunctionTok("sample_data");#NormalTok("(ps_species) ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sample_data");#NormalTok("(sd1)");],
[],
[#NormalTok("ps_species ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("tax_transform");#NormalTok("(");#StringTok("\"identity\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("dist_calc");#NormalTok("(");#StringTok("\"bray\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ord_calc");#NormalTok("(");#StringTok("\"PCoA\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ord_plot");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"arm\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"method\"");#NormalTok(")");],));
#box(image("02-contraceptive-analysis_files/figure-typst/species-ord-1.svg"))

#block[
#Skylighting(([#CommentTok("# Species table: method effect, with BV status alongside as a yardstick.");],
[#NormalTok("ps_species ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("tax_transform");#NormalTok("(");#StringTok("\"identity\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("dist_calc");#NormalTok("(");#StringTok("\"bray\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("dist_permanova");#NormalTok("(");#AttributeTok("variables =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"bv\"");#NormalTok(", ");#StringTok("\"arm\"");#NormalTok("), ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"margin\"");#NormalTok(",");],
[#NormalTok("                 ");#AttributeTok("seed =");#NormalTok(" ");#DecValTok("2026");#NormalTok(", ");#AttributeTok("n_perms =");#NormalTok(" ");#DecValTok("999");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("psExtra object - a phyloseq object with extra slots:");],
[],
[#NormalTok("phyloseq-class experiment-level object");],
[#NormalTok("otu_table()   OTU Table:         [ 220 taxa and 93 samples ]");],
[#NormalTok("sample_data() Sample Data:       [ 93 samples by 10 sample variables ]");],
[#NormalTok("tax_table()   Taxonomy Table:    [ 220 taxa by 8 taxonomic ranks ]");],
[],
[#NormalTok("psExtra info:");],
[#NormalTok("tax_agg = \"unique\" tax_trans = \"identity\" ");],
[],
[#NormalTok("bray distance matrix of size 93 ");],
[#NormalTok("0.7644328 0.8640637 0.1948786 0.8555453 0.9677946 ...");],
[],
[#NormalTok("permanova:");],
[#NormalTok("Permutation test for adonis under reduced model");],
[#NormalTok("Marginal effects of terms");],
[#NormalTok("Permutation: free");],
[#NormalTok("Number of permutations: 999");],
[],
[#NormalTok("vegan::adonis2(formula = formula, data = metadata, permutations = n_perms, by = by, parallel = parall)");],
[#NormalTok("         Df SumOfSqs      R2       F Pr(>F)    ");],
[#NormalTok("bv        2   6.8453 0.22342 13.2276  0.001 ***");],
[#NormalTok("arm       2   0.8730 0.02849  1.6869  0.075 .  ");],
[#NormalTok("Residual 88  22.7702 0.74317                   ");],
[#NormalTok("Total    92  30.6392 1.00000                   ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
The three methods do not separate on the plot. The method R² is #strong[\~3%] of the variation in species composition and sits just above the conventional significance line --- compare that with BV status, which explains #strong[\~22%] and is highly significant. Whatever the methods do to the microbiome, it is small next to the BV effect. BV status is included deliberately as a #emph[yardstick]: a known biological effect, so the method effect has a sense of scale.

== 1b. Do the gene profiles differ by method?
<b.-do-the-gene-profiles-differ-by-method>
#strong[In plain words:] same idea on the gene table, but the distances are computed differently. Gene counts are first #strong[CLR-transformed] --- the log of each gene's abundance relative to the average gene in that sample --- and then compared with plain Euclidean distance. This is needed because gene counts behave badly under Bray-Curtis: a few very long or very highly expressed genes would dominate everything.

#Skylighting(([#NormalTok("ps_genes ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as_counts");#NormalTok("(");#AttributeTok("data =");#NormalTok(" d, ");#AttributeTok("table =");#NormalTok(" ");#StringTok("\"rnaseq\"");#NormalTok(", ");#AttributeTok("min_count =");#NormalTok(" ");#DecValTok("10");#NormalTok(", ");#AttributeTok("min_samples =");#NormalTok(" ");#DecValTok("24");#NormalTok(")");],
[#NormalTok("sd0 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as");#NormalTok("(");#FunctionTok("sample_data");#NormalTok("(ps_genes), ");#StringTok("\"data.frame\"");#NormalTok(")");],
[#NormalTok("sd1 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame");#NormalTok("(meta[");#FunctionTok("match");#NormalTok("(");#FunctionTok("rownames");#NormalTok("(sd0), meta");#SpecialCharTok("$");#NormalTok("sample_id), ])");],
[#FunctionTok("rownames");#NormalTok("(sd1) ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(sd0)");],
[#FunctionTok("sample_data");#NormalTok("(ps_genes) ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sample_data");#NormalTok("(sd1)");],
[],
[#NormalTok("ps_genes_arm ");#OtherTok("<-");#NormalTok(" ps_genes ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("tax_transform");#NormalTok("(");#StringTok("\"clr\"");#NormalTok(", ");#AttributeTok("rank =");#NormalTok(" ");#StringTok("\"symbol\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("dist_calc");#NormalTok("(");#StringTok("\"euclidean\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ord_calc");#NormalTok("(");#StringTok("\"PCoA\"");#NormalTok(")");],
[],
[#NormalTok("ps_genes_arm ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ord_plot");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"arm\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"method\"");#NormalTok(")");],));
#box(image("02-contraceptive-analysis_files/figure-typst/gene-ord-arm-1.svg"))

#block[
#Skylighting(([#NormalTok("ps_genes_arm ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("dist_permanova");#NormalTok("(");#AttributeTok("variables =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"arm\"");#NormalTok("), ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"margin\"");#NormalTok(", ");#AttributeTok("seed =");#NormalTok(" ");#DecValTok("2026");#NormalTok(", ");#AttributeTok("n_perms =");#NormalTok(" ");#DecValTok("999");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("psExtra object - a phyloseq object with extra slots:");],
[],
[#NormalTok("phyloseq-class experiment-level object");],
[#NormalTok("otu_table()   OTU Table:         [ 13713 taxa and 93 samples ]");],
[#NormalTok("sample_data() Sample Data:       [ 93 samples by 10 sample variables ]");],
[#NormalTok("tax_table()   Taxonomy Table:    [ 13713 taxa by 2 taxonomic ranks ]");],
[],
[#NormalTok("otu_get(counts = TRUE)       [ 13713 taxa and 93 samples ]");],
[],
[#NormalTok("psExtra info:");],
[#NormalTok("tax_agg = \"symbol\" tax_trans = \"clr\" ");],
[],
[#NormalTok("euclidean distance matrix of size 93 ");],
[#NormalTok("97.48627 106.8722 145.2804 101.6461 105.6066 ...");],
[],
[#NormalTok("permanova:");],
[#NormalTok("Permutation test for adonis under reduced model");],
[#NormalTok("Marginal effects of terms");],
[#NormalTok("Permutation: free");],
[#NormalTok("Number of permutations: 999");],
[],
[#NormalTok("vegan::adonis2(formula = formula, data = metadata, permutations = n_perms, by = by, parallel = parall)");],
[#NormalTok("         Df SumOfSqs      R2      F Pr(>F)");],
[#NormalTok("arm       2    20282 0.02697 1.2473  0.111");],
[#NormalTok("Residual 90   731752 0.97303              ");],
[#NormalTok("Total    92   752034 1.00000              ");],));
]
]
Again no visible separation: method explains #strong[\~2.7%] of the variation in gene activity, not statistically significant at 999 permutations.

== 1c. Which genes differ between which methods?
<c.-which-genes-differ-between-which-methods>
#strong[In plain words:] PERMANOVA pools all three arms into one overall yes/no answer. DESeq2 lets us ask the three pairwise questions directly --- injectable vs pill, ring vs pill, ring vs injectable --- and produces a per-gene test with a false-discovery-rate correction (FDR, a p-value adjusted for the fact that we tested \~14,000 genes at once). DESeq2 runs on #strong[raw counts] (never CPM, never logged --- it normalises itself). We add #NormalTok("rnaseq_batch"); to the design so the sequencing batch cannot inflate the method effect, and keep genes with ≥10 raw counts in at least a quarter of the samples so that genes which are almost always zero cannot soak up statistical power.

#block[
#Skylighting(([#CommentTok("# The one safety check that matters: columns must line up with rows.");],
[#NormalTok("counts ");#OtherTok("<-");#NormalTok(" d");#SpecialCharTok("$");#NormalTok("genes[, meta");#SpecialCharTok("$");#NormalTok("sample_id]");],
[#FunctionTok("stopifnot");#NormalTok("(");#FunctionTok("identical");#NormalTok("(");#FunctionTok("colnames");#NormalTok("(counts), meta");#SpecialCharTok("$");#NormalTok("sample_id))");],
[],
[#NormalTok("keep ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rowSums");#NormalTok("(counts ");#SpecialCharTok(">=");#NormalTok(" ");#DecValTok("10");#NormalTok(") ");#SpecialCharTok(">=");#NormalTok(" ");#FunctionTok("ceiling");#NormalTok("(");#FunctionTok("nrow");#NormalTok("(meta) ");#SpecialCharTok("/");#NormalTok(" ");#DecValTok("4");#NormalTok(")");],
[#NormalTok("counts_kept ");#OtherTok("<-");#NormalTok(" counts[keep, ]");],
[#FunctionTok("cat");#NormalTok("(");#StringTok("\"Genes tested:\"");#NormalTok(", ");#FunctionTok("nrow");#NormalTok("(counts_kept), ");#StringTok("\"of\"");#NormalTok(", ");#FunctionTok("nrow");#NormalTok("(counts), ");#StringTok("\"");#SpecialCharTok("\\n");#StringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Genes tested: 13713 of 14226 ");],));
]
#Skylighting(([#NormalTok("dds_arm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("DESeqDataSetFromMatrix");#NormalTok("(");#AttributeTok("countData =");#NormalTok(" counts_kept, ");#AttributeTok("colData =");#NormalTok(" meta,");],
[#NormalTok("                                  ");#AttributeTok("design =");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" rnaseq_batch ");#SpecialCharTok("+");#NormalTok(" arm)");],
[#NormalTok("dds_arm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("DESeq");#NormalTok("(dds_arm, ");#AttributeTok("quiet =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
]
#block[
#Skylighting(([#NormalTok("arm_contrasts ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("tribble");#NormalTok("(");],
[#NormalTok("  ");#SpecialCharTok("~");#NormalTok("contrast, ");#SpecialCharTok("~");#NormalTok("args,");],
[#NormalTok("  ");#StringTok("\"injectable vs pill\"");#NormalTok(",     ");#FunctionTok("c");#NormalTok("(");#StringTok("\"arm\"");#NormalTok(", ");#StringTok("\"injectable\"");#NormalTok(", ");#StringTok("\"pill\"");#NormalTok("),");],
[#NormalTok("  ");#StringTok("\"ring vs pill\"");#NormalTok(",           ");#FunctionTok("c");#NormalTok("(");#StringTok("\"arm\"");#NormalTok(", ");#StringTok("\"ring\"");#NormalTok(", ");#StringTok("\"pill\"");#NormalTok("),");],
[#NormalTok("  ");#StringTok("\"ring vs injectable\"");#NormalTok(",     ");#FunctionTok("c");#NormalTok("(");#StringTok("\"arm\"");#NormalTok(", ");#StringTok("\"ring\"");#NormalTok(", ");#StringTok("\"injectable\"");#NormalTok(")");],
[#NormalTok(")");],
[],
[#NormalTok("genes_by_arm ");#OtherTok("<-");#NormalTok(" arm_contrasts ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("res =");#NormalTok(" ");#FunctionTok("map");#NormalTok("(args, ");#SpecialCharTok("~");#NormalTok(" ");#FunctionTok("as.data.frame");#NormalTok("(");#FunctionTok("results");#NormalTok("(dds_arm, ");#AttributeTok("contrast =");#NormalTok(" .x)) ");#SpecialCharTok("|>");],
[#NormalTok("                     ");#FunctionTok("rownames_to_column");#NormalTok("(");#StringTok("\"feature\"");#NormalTok(")),");],
[#NormalTok("         ");#AttributeTok("tested =");#NormalTok(" ");#FunctionTok("map_int");#NormalTok("(res, nrow),");],
[#NormalTok("         ");#AttributeTok("p_lt_0.05 =");#NormalTok(" ");#FunctionTok("map_int");#NormalTok("(res, ");#SpecialCharTok("~");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(.x");#SpecialCharTok("$");#NormalTok("pvalue ");#SpecialCharTok("<");#NormalTok(" ");#FloatTok("0.05");#NormalTok(", ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")),");],
[#NormalTok("         ");#AttributeTok("padj_lt_0.05 =");#NormalTok(" ");#FunctionTok("map_int");#NormalTok("(res, ");#SpecialCharTok("~");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(.x");#SpecialCharTok("$");#NormalTok("padj ");#SpecialCharTok("<");#NormalTok(" ");#FloatTok("0.05");#NormalTok(", ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("))) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(");#SpecialCharTok("-");#NormalTok("args, ");#SpecialCharTok("-");#NormalTok("res)");],
[#NormalTok("genes_by_arm");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 3 × 4");],
[#NormalTok("  contrast           tested p_lt_0.05 padj_lt_0.05");],
[#NormalTok("  <chr>               <int>     <int>        <int>");],
[#NormalTok("1 injectable vs pill  13713       707           10");],
[#NormalTok("2 ring vs pill        13713      1498           97");],
[#NormalTok("3 ring vs injectable  13713      1553          136");],));
]
]
#block[
#Skylighting(([#CommentTok("# Save the ring vs pill table with annotations for tomorrow's enrichment step.");],
[#NormalTok("genes_by_pill_ring ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("results");#NormalTok("(dds_arm, ");#AttributeTok("contrast =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"arm\"");#NormalTok(", ");#StringTok("\"ring\"");#NormalTok(", ");#StringTok("\"pill\"");#NormalTok(")) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("as.data.frame");#NormalTok("() ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("rownames_to_column");#NormalTok("(");#StringTok("\"feature\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("left_join");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("gene_info, ");#AttributeTok("by =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"feature\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#StringTok("\"ensembl_gene_id\"");#NormalTok(")) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(feature, symbol, gene_name, baseMean, log2FoldChange, lfcSE,");],
[#NormalTok("         stat, pvalue, padj)");],
[],
[#FunctionTok("write_csv");#NormalTok("(genes_by_pill_ring, ");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"genes_ring_vs_pill_studyB.csv\"");#NormalTok("))");],
[#FunctionTok("cat");#NormalTok("(");#StringTok("\"Saved\"");#NormalTok(", ");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"genes_ring_vs_pill_studyB.csv\"");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"with\"");#NormalTok(", ");#FunctionTok("nrow");#NormalTok("(genes_by_pill_ring), ");#StringTok("\"genes");#SpecialCharTok("\\n");#StringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Saved /workspaces/Data-Science-For-Biology-Workshop2_Multi-omics/data/genes_ring_vs_pill_studyB.csv with 13713 genes");],));
]
]
Out of 13,713 genes tested, only 10 pass FDR for injectable vs pill, while \~100 pass for the contrasts that involve the ring. #strong[If the methods differ from each other at all, it is mostly the ring] --- a local hormone delivery that sits in the vagina --- versus the two systemic methods.

= Question 2: does community type explain more than the method does?
<question-2-does-community-type-explain-more-than-the-method-does>
== 2a. Both groupings on the same gene ordination
<a.-both-groupings-on-the-same-gene-ordination>
#strong[In plain words:] the same gene map as above, coloured twice --- once by community type, once by method. If community type were the real driver, the colours should separate in the first panel and mix in the second.

#block[
#Skylighting(([#CommentTok("# Attach the community column to the gene phyloseq object.");],
[#NormalTok("sd0 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as");#NormalTok("(");#FunctionTok("sample_data");#NormalTok("(ps_genes), ");#StringTok("\"data.frame\"");#NormalTok(")");],
[#NormalTok("sd1 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame");#NormalTok("(meta[");#FunctionTok("match");#NormalTok("(");#FunctionTok("rownames");#NormalTok("(sd0), meta");#SpecialCharTok("$");#NormalTok("sample_id), ])");],
[#FunctionTok("rownames");#NormalTok("(sd1) ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(sd0)");],
[#FunctionTok("sample_data");#NormalTok("(ps_genes) ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sample_data");#NormalTok("(sd1)");],
[],
[#NormalTok("ps_genes_com ");#OtherTok("<-");#NormalTok(" ps_genes ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("tax_transform");#NormalTok("(");#StringTok("\"clr\"");#NormalTok(", ");#AttributeTok("rank =");#NormalTok(" ");#StringTok("\"symbol\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("dist_calc");#NormalTok("(");#StringTok("\"euclidean\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ord_calc");#NormalTok("(");#StringTok("\"PCoA\"");#NormalTok(")");],));
]
#Skylighting(([#NormalTok("gridExtra");#SpecialCharTok("::");#FunctionTok("grid.arrange");#NormalTok("(");],
[#NormalTok("  ps_genes_com ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("ord_plot");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"community\"");#NormalTok(") ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"community type\"");#NormalTok(") ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("ggtitle");#NormalTok("(");#StringTok("\"Grouped by community type\"");#NormalTok("),");],
[#NormalTok("  ps_genes_com ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("ord_plot");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"arm\"");#NormalTok(")        ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"method\"");#NormalTok(")        ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("ggtitle");#NormalTok("(");#StringTok("\"Grouped by method\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("nrow =");#NormalTok(" ");#DecValTok("1");],
[#NormalTok(")");],));
#box(image("02-contraceptive-analysis_files/figure-typst/gene-ord-com-1.svg"))

== 2b. The head-to-head PERMANOVA
<b.-the-head-to-head-permanova>
#strong[In plain words:] the two groupings compete in a single model, so each gets credit only for what it explains #emph[beyond] the other (#NormalTok("by = \"margin\"");). Degrees of freedom differ --- method has 3 levels (2 df), community 2 levels (1 df) --- which flatters the method's raw R² a little; keep that in mind when reading the numbers.

#block[
#Skylighting(([#NormalTok("ps_genes_com ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("dist_permanova");#NormalTok("(");#AttributeTok("variables =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"bv\"");#NormalTok(", ");#StringTok("\"community\"");#NormalTok(", ");#StringTok("\"arm\"");#NormalTok("), ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"margin\"");#NormalTok(",");],
[#NormalTok("                 ");#AttributeTok("seed =");#NormalTok(" ");#DecValTok("2026");#NormalTok(", ");#AttributeTok("n_perms =");#NormalTok(" ");#DecValTok("999");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("psExtra object - a phyloseq object with extra slots:");],
[],
[#NormalTok("phyloseq-class experiment-level object");],
[#NormalTok("otu_table()   OTU Table:         [ 13713 taxa and 93 samples ]");],
[#NormalTok("sample_data() Sample Data:       [ 93 samples by 10 sample variables ]");],
[#NormalTok("tax_table()   Taxonomy Table:    [ 13713 taxa by 2 taxonomic ranks ]");],
[],
[#NormalTok("otu_get(counts = TRUE)       [ 13713 taxa and 93 samples ]");],
[],
[#NormalTok("psExtra info:");],
[#NormalTok("tax_agg = \"symbol\" tax_trans = \"clr\" ");],
[],
[#NormalTok("euclidean distance matrix of size 93 ");],
[#NormalTok("97.48627 106.8722 145.2804 101.6461 105.6066 ...");],
[],
[#NormalTok("permanova:");],
[#NormalTok("Permutation test for adonis under reduced model");],
[#NormalTok("Marginal effects of terms");],
[#NormalTok("Permutation: free");],
[#NormalTok("Number of permutations: 999");],
[],
[#NormalTok("vegan::adonis2(formula = formula, data = metadata, permutations = n_perms, by = by, parallel = parall)");],
[#NormalTok("          Df SumOfSqs      R2      F Pr(>F)");],
[#NormalTok("bv         2    13899 0.01848 0.8555  0.745");],
[#NormalTok("community  1     9431 0.01254 1.1610  0.241");],
[#NormalTok("arm        2    19664 0.02615 1.2103  0.130");],
[#NormalTok("Residual  87   706735 0.93976              ");],
[#NormalTok("Total     92   752034 1.00000              ");],));
]
]
On the gene ordination, method explains #strong[\~2.6%] and community type #strong[\~1.5%], both nonsignificant, and BV status explains least of all (\~1.8%). Even allowing for the degrees-of-freedom difference, #strong[the ordination says neither grouping explains much, and method does not lose to community].

== 2c. The head-to-head DESeq2
<c.-the-head-to-head-deseq2>
#strong[In plain words:] ordinations pool everything into one number. The gene-by-gene test counts how many #emph[individual genes] actually pass FDR under each grouping --- a second, sharper lens on the same comparison.

#block[
#Skylighting(([#NormalTok("dds_com ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("DESeqDataSetFromMatrix");#NormalTok("(");#AttributeTok("countData =");#NormalTok(" counts_kept, ");#AttributeTok("colData =");#NormalTok(" meta,");],
[#NormalTok("                                  ");#AttributeTok("design =");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" rnaseq_batch ");#SpecialCharTok("+");#NormalTok(" community)");],
[#NormalTok("dds_com ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("DESeq");#NormalTok("(dds_com, ");#AttributeTok("quiet =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[],
[#NormalTok("genes_by_community ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("results");#NormalTok("(dds_com, ");#AttributeTok("contrast =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"community\"");#NormalTok(", ");#StringTok("\"lacto-dominant\"");#NormalTok(", ");#StringTok("\"diverse\"");#NormalTok(")) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("as.data.frame");#NormalTok("() ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("rownames_to_column");#NormalTok("(");#StringTok("\"feature\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("left_join");#NormalTok("(d");#SpecialCharTok("$");#NormalTok("gene_info, ");#AttributeTok("by =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"feature\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#StringTok("\"ensembl_gene_id\"");#NormalTok(")) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(feature, symbol, gene_name, baseMean, log2FoldChange, lfcSE,");],
[#NormalTok("         stat, pvalue, padj)");],
[],
[#FunctionTok("bind_rows");#NormalTok("(genes_by_arm, ");#FunctionTok("tibble");#NormalTok("(");#AttributeTok("contrast =");#NormalTok(" ");#StringTok("\"lacto-dominant vs diverse\"");#NormalTok(")) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("p_lt_0.05 =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(genes_by_arm");#SpecialCharTok("$");#NormalTok("p_lt_0");#FloatTok(".05");#NormalTok(", ");#FunctionTok("sum");#NormalTok("(genes_by_community");#SpecialCharTok("$");#NormalTok("pvalue ");#SpecialCharTok("<");#NormalTok(" ");#FloatTok("0.05");#NormalTok(", ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")),");],
[#NormalTok("    ");#AttributeTok("padj_lt_0.05 =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(genes_by_arm");#SpecialCharTok("$");#NormalTok("padj_lt_0");#FloatTok(".05");#NormalTok(", ");#FunctionTok("sum");#NormalTok("(genes_by_community");#SpecialCharTok("$");#NormalTok("padj ");#SpecialCharTok("<");#NormalTok(" ");#FloatTok("0.05");#NormalTok(", ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")),");],
[#NormalTok("    ");#AttributeTok("tested =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(genes_by_arm");#SpecialCharTok("$");#NormalTok("tested, ");#FunctionTok("nrow");#NormalTok("(genes_by_community))");],
[#NormalTok("  ) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(contrast, tested, p_lt_0");#FloatTok(".05");#NormalTok(", padj_lt_0");#FloatTok(".05");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 4 × 4");],
[#NormalTok("  contrast                  tested p_lt_0.05 padj_lt_0.05");],
[#NormalTok("  <chr>                      <int>     <int>        <int>");],
[#NormalTok("1 injectable vs pill         13713       707           10");],
[#NormalTok("2 ring vs pill               13713      1498           97");],
[#NormalTok("3 ring vs injectable         13713      1553          136");],
[#NormalTok("4 lacto-dominant vs diverse  13713      2204          310");],));
]
]
#block[
#Skylighting(([#FunctionTok("write_csv");#NormalTok("(genes_by_community, ");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"genes_by_community_studyB.csv\"");#NormalTok("))");],
[#FunctionTok("cat");#NormalTok("(");#StringTok("\"Saved\"");#NormalTok(", ");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"genes_by_community_studyB.csv\"");#NormalTok("), ");#StringTok("\"");#SpecialCharTok("\\n");#StringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Saved /workspaces/Data-Science-For-Biology-Workshop2_Multi-omics/data/genes_by_community_studyB.csv ");],));
]
]
By this measure #strong[community type wins clearly]: 310 genes pass FDR for lacto-dominant vs diverse, versus 10--136 for any pairwise method contrast.

== 2d. What are those community genes doing?
<d.-what-are-those-community-genes-doing>
#strong[In plain words:] a volcano plot. Every dot is one gene: left--right position says #emph[which way] it shifts (positive = higher in lacto-dominant), height says #emph[how strong the evidence is] (higher = smaller p-value). Dots above the dashed line pass the significance cut. The ten strongest genes are labelled by their gene symbol so a biologist can eyeball whether they make sense.

#Skylighting(([#NormalTok("vol ");#OtherTok("<-");#NormalTok(" genes_by_community ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("direction =");#NormalTok(" ");#FunctionTok("case_when");#NormalTok("(");],
[#NormalTok("      ");#FunctionTok("is.na");#NormalTok("(padj) ");#SpecialCharTok("|");#NormalTok(" padj ");#SpecialCharTok(">=");#NormalTok(" ");#FloatTok("0.05");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" ");#StringTok("\"not significant\"");#NormalTok(",");],
[#NormalTok("      log2FoldChange ");#SpecialCharTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" ");#StringTok("\"higher in lacto-dominant\"");#NormalTok(",");],
[#NormalTok("      log2FoldChange ");#SpecialCharTok("<");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" ");#StringTok("\"higher in diverse\"");],
[#NormalTok("    ),");],
[#NormalTok("    ");#AttributeTok("neg_log_p =");#NormalTok(" ");#SpecialCharTok("-");#FunctionTok("log10");#NormalTok("(pvalue)");],
[#NormalTok("  )");],
[],
[#NormalTok("top10 ");#OtherTok("<-");#NormalTok(" vol ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("filter");#NormalTok("(padj ");#SpecialCharTok("<");#NormalTok(" ");#FloatTok("0.05");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("slice_min");#NormalTok("(padj, ");#AttributeTok("n =");#NormalTok(" ");#DecValTok("10");#NormalTok(")");],
[],
[#FunctionTok("ggplot");#NormalTok("(vol, ");#FunctionTok("aes");#NormalTok("(log2FoldChange, neg_log_p, ");#AttributeTok("colour =");#NormalTok(" direction)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#FloatTok("0.7");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ggrepel");#SpecialCharTok("::");#FunctionTok("geom_text_repel");#NormalTok("(");#AttributeTok("data =");#NormalTok(" top10, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("label =");#NormalTok(" symbol),");],
[#NormalTok("                           ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("2.8");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"black\"");#NormalTok(", ");#AttributeTok("max.overlaps =");#NormalTok(" ");#DecValTok("20");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_hline");#NormalTok("(");#AttributeTok("yintercept =");#NormalTok(" ");#SpecialCharTok("-");#FunctionTok("log10");#NormalTok("(");#FloatTok("0.05");#NormalTok("), ");#AttributeTok("linetype =");#NormalTok(" ");#StringTok("\"dashed\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_vline");#NormalTok("(");#AttributeTok("xintercept =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("linetype =");#NormalTok(" ");#StringTok("\"dashed\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_colour_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"steelblue\"");#NormalTok(", ");#StringTok("\"grey75\"");#NormalTok(", ");#StringTok("\"tomato\"");#NormalTok(")) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Genes by community type (defined from the species table)\"");#NormalTok(",");],
[#NormalTok("       ");#AttributeTok("subtitle =");#NormalTok(" ");#StringTok("\"310 genes pass FDR 0.05; top 10 by adjusted p-value labelled\"");#NormalTok(",");],
[#NormalTok("       ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"log2 fold change  → higher in lacto-dominant\"");#NormalTok(",");],
[#NormalTok("       ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"-log10 raw p-value\"");#NormalTok(",");],
[#NormalTok("       ");#AttributeTok("colour =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#box(image("02-contraceptive-analysis_files/figure-typst/volcano-1.svg"))

= Verdict
<verdict>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Question], [Test], [Answer],),
  table.hline(),
  [Do the methods differ?], [Species PERMANOVA], [R² \~3%, borderline (p ≈ 0.08) --- a weak signal at best],
  [Do the methods differ?], [Gene PERMANOVA], [R² \~2.7%, not significant],
  [Do the methods differ?], [DESeq2 pairwise], [Mostly ring vs the other two (\~100 FDR genes); injectable vs pill ≈ nothing],
  [Community vs method on genes?], [Gene PERMANOVA], [method \~2.6% \> community \~1.5%; neither significant],
  [Community vs method on genes?], [DESeq2 FDR gene counts], [community 310 \> any method contrast],
)
#strong[Main question:] the three hormonal methods do not produce clearly different vaginal transcriptomes or microbiomes in this cohort. The only structure worth chasing is #strong[ring vs the systemic methods] (\~100 genes each way), while injectable and pill are nearly indistinguishable. Even that signal is small: method never explains more than \~3% of the overall variation, and BV status dwarfs it on the species table (\~22%).

#strong[Sub-question:] the two lenses disagree, and that is the interesting result. On the ordination (one pooled number), method slightly out-explains community type, though both are weak and neither is significant. On the gene-by-gene test, community type finds more than twice as many FDR-significant genes as the best method contrast (310 vs 136). So community type is the stronger #emph[target] if you want a gene list to interpret, but the pooled variation it explains is still small --- and remember the community type was defined from the #emph[species] table, which is why we tested it only on genes.

#strong[Spot-check:] rerun #NormalTok("sum(genes_by_community$padj < 0.05, na.rm = TRUE)"); --- it should be 310. Then open the volcano and check that the labelled top-10 points all sit above the dashed line: if any sit below it, I made an error.

= How to check this yourself
<how-to-check-this-yourself>
Open #NormalTok("02-contraceptive_effect.qmd"); in the #NormalTok("group_project/"); folder --- it is the working version of this report with the same code. The most useful single check is #NormalTok("sum(genes_by_community$padj < 0.05, na.rm = TRUE)"); = #strong[310]\; if it matches, the whole DESeq2 pipeline ran as shown. The two exported gene tables (#NormalTok("genes_ring_vs_pill_studyB.csv");, #NormalTok("genes_by_community_studyB.csv");) are in #NormalTok("data/"); and open in any spreadsheet program.

= Choices made
<choices-made>
- Defined community type #strong[from the species table only] (Lactobacillus fraction split at 0.5) and tested it on genes. #emph[Alternative not chosen:] a three-way type (L. crispatus / L. iners / Gardnerella) --- I checked it and it explained no more of the gene ordination (R² 2.4% vs 1.5%) while being harder to explain.
- Tested community type on #strong[genes only], never on the species table it was defined from. #emph[Alternative not chosen:] the circular test.
- Used #strong[Bray-Curtis] for species and #strong[CLR + Euclidean] for genes. #emph[Alternative not chosen:] Bray-Curtis on raw gene counts, which is dominated by library size.
- Included #NormalTok("rnaseq_batch"); in both DESeq2 designs (the QC report showed it is balanced across arms). #emph[Alternative not chosen:] a design without it, which risks inflating group differences with batch differences.
- Kept genes with #strong[≥10 raw counts in ≥24 samples] (a quarter of 93) for both the ordination (13,760 symbols) and DESeq2 (13,713 genes). #emph[Alternative not chosen:] no filter, which wastes permutations on genes that are almost always zero.
- Entered BV status in the PERMANOVAs as a #strong[yardstick] to size the method effect against a known biological effect. #emph[Alternative not chosen:] leave it out and have no sense of scale.
- Used #NormalTok("by = \"margin\""); (each term's effect given the others). #emph[Alternative not chosen:] #NormalTok("by = \"terms\"");, where the first term listed absorbs more credit.
- DESeq2 contrasts coded as #strong[injectable vs pill, ring vs pill, ring vs injectable] with pill as reference. #emph[Alternative not chosen:] a likelihood-ratio test of the 3-level factor as a whole, which would hide which pair drives the difference.
- No samples were dropped. #emph[Alternative not chosen:] excluding B018/B029 --- their missing cytokines do not affect the count tables used here.
