suppressPackageStartupMessages({
  library(tidyverse); library(here); library(DESeq2)
})
source(here("R/count_tables.R"))
d <- read_counts("group_b")
meta <- d$metadata
tax <- d$taxonomy

lacto <- d$species[tax$taxon[tax$Genus == "Lactobacillus"], , drop = FALSE]
meta$lacto_fraction <- colSums(lacto) / colSums(d$species)
meta$community <- cut(meta$lacto_fraction, c(-.01, .5, 1.01),
                      labels = c("diverse", "lacto-dominant"))

# three-way community from the species table, for comparison
g3 <- t(t(d$species) / colSums(d$species))
get_frac <- function(g) colSums(g3[g$taxon[g$Genus == g], , drop = FALSE])
meta$cst <- cut(meta$lacto_fraction, c(-.01,.5,1.01), labels = c("diverse","lacto"))
# also Gardnerella fraction
meta$gard <- colSums(g3[tax$taxon[tax$Genus=="Gardnerella"],,drop=FALSE])
print(table(meta$community, meta$arm))

# ---- DESeq2 genes ----
keep <- rowSums(d$genes >= 10) >= ceiling(nrow(meta)/4)
counts <- d$genes[keep, meta$sample_id]
cat("genes tested:", nrow(counts), "\n")
stopifnot(identical(colnames(counts), meta$sample_id))

dds1 <- DESeqDataSetFromMatrix(countData = counts, colData = meta,
                               design = ~ rnaseq_batch + arm)
dds1 <- DESeq(dds1, quiet = TRUE)
contr <- list(c("arm", "injectable", "pill"), c("arm", "ring", "pill"), c("arm", "ring", "injectable"))
for (ct in contr) {
  r <- as.data.frame(results(dds1, contrast = ct))
  cat("contrast", paste(ct, collapse=" vs "), ": padj<0.05 =", sum(r$padj < 0.05, na.rm=TRUE),
      " p<0.05 =", sum(r$pvalue < 0.05, na.rm=TRUE), "\n")
}
resA <- results(dds1, contrast = c("arm","ring","pill")) |> as.data.frame() |> rownames_to_column("feature")

dds2 <- DESeqDataSetFromMatrix(countData = counts, colData = meta,
                               design = ~ rnaseq_batch + community)
dds2 <- DESeq(dds2, quiet = TRUE)
resC <- results(dds2, contrast = c("community","lacto-dominant","diverse")) |> as.data.frame()
cat("community contrast: padj<0.05 =", sum(resC$padj < 0.05, na.rm=TRUE),
    " p<0.05 =", sum(resC$pvalue < 0.05, na.rm=TRUE), "\n")

# overlap
a05 <- rownames_to_column(resA, "feature") |> filter(padj < 0.05) |> pull(feature)
c05 <- rownames_to_column(resC, "feature") |> filter(padj < 0.05) |> pull(feature)
cat("overlap of significant gene sets:", length(intersect(a05, c05)), "\n")
