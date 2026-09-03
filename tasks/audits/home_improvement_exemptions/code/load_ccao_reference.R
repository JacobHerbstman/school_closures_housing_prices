# Read only the pinned characteristic/township functions and dictionaries.
# Strip their ccao:: namespace qualifier so they resolve to these same pinned
# objects, without installing the package's unrelated AWS/valuation dependencies.
required_packages <- c("arrow", "data.table", "digest", "dplyr", "jsonlite", "magrittr", "rlang", "tidyr")
stopifnot(all(vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)))

ccao <- new.env(parent = globalenv())
ccao$`%>%` <- magrittr::`%>%`
archive_members <- unzip("../input/ccao.zip", list = TRUE)
for (filename in c("town_dict", "vars_dict", "chars_cols")) {
  connection <- unz(
    "../input/ccao.zip",
    paste0("ccao-419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a/data/", filename, ".rda"),
    open = "rb"
  )
  member_size <- archive_members$Length[endsWith(archive_members$Name, paste0("/data/", filename, ".rda"))]
  stopifnot(length(member_size) == 1L)
  dictionary <- rawConnection(memDecompress(readBin(connection, "raw", n = member_size), "bzip2"))
  load(dictionary, envir = ccao)
  close(dictionary)
  close(connection)
}
for (filename in c("town_funs.R", "chars_funs.R")) {
  connection <- unz(
    "../input/ccao.zip",
    paste0("ccao-419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a/R/", filename)
  )
  reference_code <- readLines(connection, warn = FALSE)
  close(connection)
  eval(parse(text = gsub("ccao::", "", reference_code, fixed = TRUE)), envir = ccao)
}
rm(connection, dictionary, filename, member_size, archive_members, reference_code)
