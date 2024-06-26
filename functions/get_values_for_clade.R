#' Returns a dataframe of values for a given clade
#'
#' @param gb A grambank CLDF object
#' @param glottocode The glottocode of the relevant clade
#' @return data-frame of ValueTable without duplicates
#' @importFrom dplyr filter
#' @author Simon Greenhill
#' @examples

#' @export
get_values_for_clade <- function(gb, glottocode) {
    languages <- gb$tables$LanguageTable %>%
        dplyr::filter(grepl(glottocode, lineage))
    gb$tables$ValueTable %>%
        dplyr::filter(Language_ID %in% languages$ID)
}

