# Compare Bray-Curtis vs Jaccard on the species table
library(vegan)   # vegdist, adonis2
library(cluster) # silhouette
source(here::here("R/count_tables.R"))
d <- read_counts("instructional")

md <- d$metadata
sp <- t(d$species)          # flip: samples in rows, species in columns
stopifnot(identical(rownames(sp), md$sample_id))  # order check

md$community <- paste(md$outcome, md$time_point, sep = "_")  # 6 known groups

# Bray-Curtis: uses abundances. Jaccard: presence/absence only.
bc  <- vegdist(sp, method = "bray")
jac <- vegdist(sp, method = "jaccard", binary = TRUE)

# PERMANOVA: how much of the distance structure is explained by the groups (R^2)
for (dd in list(bc, jac)) {
  for (v in c("outcome", "time_point", "community")) {
    a <- adonis2(dd ~ md[[v]], permutations = 999)
    cat(sprintf("%-10s %-12s R2 = %.3f  p = %.3f\n",
                if (identical(dd, bc)) "Bray" else "Jaccard",
                v, a$R2[1], a$`Pr(>F)`[1]))
  }
}

# Silhouette: how well each sample sits inside its own group vs neighbours
for (dd in list(bc, jac)) {
  grp <- as.integer(factor(md$community))   # integer codes for silhouette
  s <- silhouette(grp, dist = dd)
  cat(sprintf("%-10s mean silhouette = %.3f\n",
              if (identical(dd, bc)) "Bray" else "Jaccard", mean(s[, 3])))
}
