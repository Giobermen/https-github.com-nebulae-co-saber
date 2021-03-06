library("dplyr")
library("readr")
library("curl")

make_dir_if_not_exists <- function(dir){
  if (!dir.exists(dir)) dir.create(dir)
}

# Get data:

ftp_auth <- readLines(con = file.path("data-raw", "ftp_auth"))
server <- paste0("ftp://", ftp_auth, "@ftp.icfes.gov.co/SABER11/")

con <- curl(server, "r", new_handle(dirlistonly = TRUE))

files <- grep(pattern = ".zip", x = readLines(con), fixed = TRUE, value = TRUE)
file_name <- function(file){gsub("-", "_", substr(file, 1, 10), fixed = TRUE)}

close(con)

download_if_not_exists <- function(url, destfile){
  if (!file.exists(destfile))
      curl_download(url, destfile)
  file.exists(destfile)
}

devtools::use_data_raw()

Map(download_if_not_exists, destfile = file.path("data-raw", "raw", files),
    url = paste0(server, files))

# Read data

## Read or make file with column types

make_dir_if_not_exists(file.path("data-raw", "types"))

get_types <- function(file, ...){
  types_file <- file.path("data-raw", "types", paste0(file_name(file), ".csv"))

  # If there is no types file, make with defaults
  # else read types file and parse types list for readr use.
  if (!file.exists(file.path(types_file))){
    df <- read_delim(file.path("data-raw", "raw", file), del = "|",
                     na = c("---", "-1", "", "            "), n_max = 100)

    types_df <- data_frame(Variable = names(df), Tipo = sapply(df, typeof)) %>%
      mutate(Tipo = ifelse(Tipo == "double", paste0("col_euro_", Tipo, "()"),
                           paste0("col_", Tipo, "()")))

    write_csv(types_df, types_file)
    lapply(parse(text = types_df[["Tipo"]]), eval)
  } else {
    types_df <- read_csv(types_file)
    setNames(lapply(parse(text = types_df[["Tipo"]]), eval),
             types_df[["Variable"]])
  }
}

columns <- lapply(files, get_types)

read_save <- function(file, ...){
  nas <- c("---", "-1", "", "            ")

  df <- list(read_delim(file.path("data-raw", "raw", file), del = "|",
                        na = nas, ...))

  names(df) <- file_name(file)

  save(list = names(df), file = file.path("data", paste0(names(df), ".rda")),
       envir = as.environment(df), compress = "bzip2")
}


## Get problems to edit types

# get_problems <- function(file){
#   nas <- c("---", "-1", "", "            ")
#   columns <- get_types(file)
#   df <- read_delim(file.path("data-raw", "raw", file), del = "|",
#                    col_types = columns, na = nas)
#   problems(df)
# }

# probs <- lapply(files, get_problems)

## Test
# read_save(file = files[1], col_types = columns[[1]])

make_dir_if_not_exists(file.path("data"))

Map(read_save, file = files, col_types = columns)
