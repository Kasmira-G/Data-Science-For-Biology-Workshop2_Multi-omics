suppressPackageStartupMessages({
  library(tidyverse); library(here); library(microViz); library(phyloseq)
})
source(here("R/count_tables.R"))
d <- read_counts("group_b")
meta <- d$metadata

# community type from the MICROBIOME table only
tax <- d$taxonomy
lacto_taxa <- tax$taxon[tax$Genus == "Lactobacillus"]
lacto <- d$species[lacto_taxa, , drop = FALSE]
lacto_frac <- colSums(lacto) / colSums(d$species)
meta <- meta |> mutate(
  lacto_fraction = lacto_frac[sample_id],
  community = cut(lacto_fraction, c(-0.01, 0.5, 1.01),
                  labels = c("diverse", "lacto-dominant"))
)
print(table(meta$community, meta$arm))

attach_meta <- function(ps, meta) {
  sd0 <- as(sample_data(ps), "data.frame")   # rownames = sample ids, in ps order
  sd1 <- as.data.frame(meta[match(rownames(sd0), meta$sample_id), ])
  rownames(sd1) <- rownames(sd0)
  sample_data(ps) <- sample_data(sd1)
  ps
}

# ---- species ordination + PERMANOVA (arm) ----
ps_sp <- attach_meta(as_counts(data = d, table = "microbiome"), meta) |>
  tax_transform("identity") |> dist_calc("bray")
pm1 <- ps_sp |> dist_permanova(variables = c("arm"), seed = 1, n_perms = 999)
print(pm1)
pm1b <- ps_sp |> dist_permanova(variables = c("bv", "arm"), seed = 1, n_perms = 999, by = "margin")
print(pm1b)

# ---- genes: filter, clr-euclidean, PERMANOVA arm + community ----
ps_ge <- attach_meta(as_counts(data = d, table = "rnaseq", min_count = 10, min_samples = 23), meta) |>
  tax_transform("clr", rank = "symbol") |> dist_calc("euclidean")
cat("genes kept:", ntaxa(ps_ge), "of", nrow(d$genes), "\n")
pm2 <- ps_ge |> dist_permanova(variables = c("arm"), seed = 1, n_perms = 999)
print(pm2)
pm3 <- ps_ge |> dist_permanova(variables = c("community", "arm"), seed = 1, n_perms = 999, by = "margin")
print(pm3)
