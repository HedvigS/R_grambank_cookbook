#' Calculates which features are shared between two languages
#'
#' @param gb A grambank CLDF object
#' @param language1 The glottocode of language 1
#' @param language2 The glottocode of language 2
#' @return a list of:
#'  - `compared` (the number of parameters in grambank for this pair of languages)
#'  - `identical` (the number of identical features for this pair)
#'  - `features` (a dataframe of the features)
#' @export
#' @importFrom dplyr filter
#' @importFrom dplyr select
#' @importFrom dplyr mutate
#' @importFrom dplyr left_join
#' @importFrom dplyr join_by
#' @importFrom tidyr spread
#' @importFrom tidyr drop_na
#' @author Simon Greenhill
#' @examples

get_shared_features <- function(gb, language1, language2) {
    df <- gb$tables$ValueTable %>%
        # select languages
        dplyr::filter(Language_ID %in% c(language1, language2)) %>%
        # remove "?"
        dplyr::filter(Value != "?") %>%
        # select columns
        dplyr::select(Language_ID, Parameter_ID, Value) %>%
        # widen
        tidyr::spread(key = Language_ID, value = Value, drop = FALSE) %>%
        # remove NAs
        tidyr::drop_na() %>%
        # tag shared features
        dplyr::mutate(shared = .data[[language1]] == .data[[language2]]) %>%
        # add feature name
        dplyr::left_join(
            gb$tables$ParameterTable %>% dplyr::select(ID, Name),
            dplyr::join_by(Parameter_ID==ID))

    list(
        compared=nrow(df),
        identical=nrow(subset(df, shared==TRUE)),
        features=subset(df, shared==TRUE)
    )
}

