#!/usr/bin/env Rscript
# Build a static completion index for the R bundle: one "alias<TAB>package"
# line per help alias, byte-sorted, plus a meta file recording the library
# paths and their mtimes for staleness checks.
#
# Usage: Rscript buildCompletionIndex.R <index-out> <meta-out>
# Run with LC_ALL=C so sort() orders bytes the same way grep does.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("usage: buildCompletionIndex.R <index-out> <meta-out>")
index_out <- args[1L]
meta_out <- args[2L]

# Force the help-search database build, as the helper daemon does (ASCII-only
# pattern: the builder runs under LC_ALL=C, where non-ASCII breaks grep()).
invisible(help.search("^Zxq!#%$"))
db <- utils:::.hsearch_db()
a <- db$Alias[, c(1L, 3L), drop = FALSE]
# Same exclusions the daemon applied: operators, S3-method-ish aliases, self.
keep <- grep("[<,]|-(class|package|method(s)?)|TM_Rdaemon", a[, 1L], invert = TRUE)
a <- a[keep, , drop = FALSE]
lines <- sort(paste(a[, 1L], a[, 2L], sep = "\t"))

libs <- .libPaths()
mtime <- vapply(libs, function(d) {
  m <- tryCatch(as.integer(file.mtime(d)), error = function(e) NA_integer_)
  if (is.na(m)) "-1" else format(m, scientific = FALSE)
}, character(1L))
meta <- paste(libs, mtime, sep = "\t")

tmp_index <- paste0(index_out, ".tmp")
tmp_meta <- paste0(meta_out, ".tmp")
writeLines(lines, tmp_index, useBytes = TRUE)
writeLines(meta, tmp_meta, useBytes = TRUE)
invisible(file.rename(tmp_index, index_out))
invisible(file.rename(tmp_meta, meta_out))
cat(length(lines), "completion entries\n")
