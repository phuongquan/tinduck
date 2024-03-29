#' Convert supplied df into required format for generating tables/plots
#'
#' Supplied df needs to be long (at least for now)
#'
#' @param df A data frame containing multiple time series in long format
#' @param timepoint_col Name of column to be used for x-axes
#' @param item_col Name of column containing categorical values identifying distinct time series
#' @param value_col Name of column containing the time series values which will be used for the y-axes.
#' @param plot_value_type "value" or "delta"
#' @param timepoint_limits Set start and end dates for time period to include. Defaults to min/max of timepoint_col
#' @param fill_with_zero Replace any missing or NA values with 0? Useful when value_col is a record count
#' @param item_order vector of values contained in item_col, for ordering the items in the table. Any values not mentioned are included alphabetically at the end
#'
#' @return data frame
#' @noRd
prepare_table <-
  function(df,
           timepoint_col,
           item_col,
           value_col,
           plot_value_type = "value",
           timepoint_limits = c(NA, NA),
           fill_with_zero = FALSE,
           item_order = NULL) {

  # TODO: allow df to be passed in wide with vector of value_cols?

  # initialise column names to avoid R CMD check Notes
  timepoint <- item <- value <- value_for_history <- NULL

  # validate inputs

  # rename cols for ease. may want to figure out how to keep original colnames
  table_df <-
    df %>%
    dplyr::rename(timepoint = dplyr::all_of(timepoint_col),
                  item = dplyr::all_of(item_col),
                  value = dplyr::all_of(value_col))

  table_df <-
    align_data_timepoints(df = table_df,
                          timepoint_limits = timepoint_limits)

  if (fill_with_zero) {
    table_df <-
      table_df %>%
      tidyr::replace_na(list(value = 0))
  }

  # add history column
  table_df <-
    table_df %>%
    dplyr::group_by(item) %>%
    dplyr::arrange(timepoint) %>%
    dplyr::mutate(
      value_for_history = dplyr::case_when(
        plot_value_type == "value" ~ as.numeric(value),
        plot_value_type == "delta" ~ as.numeric(value) - dplyr::lag(as.numeric(value))
      )
    ) %>%
    dplyr::summarise(
      last_timepoint = max_else_na(timepoint[!is.na(value)]),
      last_value = rev(value)[1],
      # TODO: add last_value_nonmissing
      max_value = max_else_na(value),
      # TODO: match precision to values
      mean_value = round(mean(value, na.rm = TRUE),
                   digits = 1),
      # TODO: drop this as not useful
      mean_value_last14 = round(mean(rev(value)[1:14], na.rm = TRUE),
                          digits = 1),
      history = history_to_list(value_for_history,
                                timepoint,
                                plot_value_type),
      .groups = "drop"
    )

  if (!is.null(item_order)) {
    table_df <-
      table_df %>%
      dplyr::arrange(factor(item, levels = item_order))
  }

  table_df
}


#' Specify relevant columns in the source data frame
#'
#' @param timepoint_col String denoting the (datetime) column which will be used for the x-axes.
#' @param item_col String denoting the (character) column containing categorical values identifying
#'   distinct time series.
#' @param value_col String denoting the (numeric) column containing the time series values which
#'   will be used for the y-axes.
#' @param group_col Optional. String denoting the (character) column containing categorical values
#'   which will be used to group the time series into different tabs on the report.
#'
#' @return A `colspec()` object
#' @export
colspec <- function(timepoint_col,
                    item_col,
                    value_col,
                    group_col = NULL){
  structure(
    list(timepoint_col = timepoint_col,
       item_col = item_col,
       value_col = value_col,
       group_col = group_col),
    class = "tinduck_colspec")
}

#' Specify output options for the report
#'
#' @param plot_value_type Display the raw "`value`" for the time series or display the calculated
#'   "`delta`" between consecutive values.
#' @param plot_type Display the time series as a "`bar`" or "`line`" chart.
#' @param item_label String label to use for the "item" column in the report.
#' @param plot_label String label to use for the time series column in the report.
#' @param summary_cols Summary data to include as columns in the report. Options are `c("max_value",
#'   "last_value", "last_timepoint", "mean_value", "mean_value_last14")`.
#' @param sync_axis_range Set the y-axis to be the same range for all time series in a table.
#'   X-axes are always synced.
#'
#' @return An `outputspec()` object
#' @export
outputspec <- function(plot_value_type = "value",
                       plot_type = "bar",
                       item_label = "Item",
                       plot_label = "History",
                       summary_cols = c("max_value"),
                       sync_axis_range = FALSE){

  structure(
    list(plot_value_type = plot_value_type,
         plot_type = plot_type,
         item_label = item_label,
         plot_label = plot_label,
         summary_cols = summary_cols,
         sync_axis_range = sync_axis_range),
    class = "tinduck_outputspec")
}

history_to_list <-
  function(value_for_history,
           timepoint,
           plot_value_type) {

    ts <-
      data.frame(value_for_history,
                 timepoint,
                 row.names = 2) %>%
      xts::as.xts() %>%
      list()
    names(ts[[1]]) <- plot_value_type
    ts
  }


#' Align the timepoint values across all items
#'
#' @param df Data frame with 3 columns: timepoint, item, and value
#' @param timepoint_limits Vector containing min and max dates for the x-axes. Use Date type.
#'
#' Ensure timepoint values are the same for all items, for consistency down the table.
#' Also can restrict/expand data to a specified period here as cannot set xlimits in dygraphs.
#' # TODO: THIS CURRENTLY ONLY WORKS FOR DAILY TIMEPOINTS
#'
#' @return Data frame with consistent timepoints
#' @noRd
align_data_timepoints <-
  function(df,
           timepoint_limits = c(NA, NA)) {

  # initialise column names to avoid R CMD check Notes
  timepoint <- item <- value <- NULL

  # TODO: Need to work out correct limits to use based on df
  #  in case supplied limits don't match df granularity
  if (is.na(timepoint_limits[1])) {
    min_timepoint <- min(df$timepoint)
  } else{
    min_timepoint <- timepoint_limits[1]
  }
  if (is.na(timepoint_limits[2])) {
    max_timepoint <- max(df$timepoint)
  } else{
    max_timepoint <- timepoint_limits[2]
  }

  # TODO: Need to work out correct granularity to use based on df
  #  as don't want to insert unnecessary rows
  all_timepoints <- seq(min_timepoint, max_timepoint, by = "day")

  df_out <-
    df %>%
    tidyr::pivot_wider(names_from = item,
                       values_from = value,
                       names_prefix = "piv_") %>%
    # insert any missing timepoint values
    dplyr::full_join(data.frame("timepoint" = all_timepoints), by = "timepoint") %>%
    # restrict to specified limits
    dplyr::filter(timepoint >= min_timepoint & timepoint <= max_timepoint) %>%
    tidyr::pivot_longer(cols = dplyr::starts_with("piv_"),
                        names_to = "item",
                        names_prefix = "piv_")

  df_out

}


#' Wrapper for max function
#'
#' Returns NA (instead of Inf) if all values are NA. Retains datatype and avoids using suppressWarnings.
#'
#' @param x vector of values
#'
#' @return Maximum value excluding NAs
#' @noRd
max_else_na <- function(x){
  if (all(is.na(x))) {
    if ("Date" %in% class(x)) {
      as.Date(NA)
    } else{
      NA_real_
    }
  } else{
    max(x, na.rm = TRUE)
  }
}

#' Validate the supplied df against the supplied colspec
#'
#' If there are any validation errors, these are all compiled before calling a
#' single stop()
#'
#' @param df user supplied df
#' @param colspec user supplied colspec
#'
#' @noRd
validate_df_to_colspec <- function(df,
                                   colspec){

  # validate - collect all errors together and return only once
  err_validation <- character()

  # check supplied colnames against df
  # drop any items in the colspec that are NULL
  colspec_vector <- unlist(colspec)
  # ignore any columns in df that are not in specification
  dfnames <- names(df)[names(df) %in% colspec_vector]

  # check for duplicate names in df
  if (anyDuplicated(dfnames) > 0) {
    err_validation <-
      append(
        err_validation,
        paste(
          "Duplicate column names in data: [",
          paste(dfnames[duplicated(dfnames)], collapse = ", "),
          "]"
        )
      )
  }
  # check for duplicate names in colspec
  if (anyDuplicated(colspec_vector) > 0) {
    err_validation <-
      append(
        err_validation,
        paste(
          "Duplicate column names in colspec: [",
          paste(colspec_vector[duplicated(colspec_vector)], collapse = ", "),
          "]. Each colspec parameter must refer to a different column in the df "
        )
      )
  }
  # check supplied colnames are present in df
  for (i in seq_along(colspec_vector)){
    if (!colspec_vector[i] %in% dfnames) {
      err_validation <-
        append(
          err_validation,
          paste(
            names(colspec_vector)[i],
            "specified to be [",
            colspec_vector[i],
            "] but column is not present in the df"
          )
        )
    }
  }

  # TODO: check timepoints in df are distinct per item
  # duplicate_timepoints <-
  #   df %>%
  #   dplyr::group_by(across(colspec$item_col)) %>%
  #   dplyr::summarise(duplicate_timepoints = anyDuplicated(timepoint_col)) %>%
  #   dplyr::filter(duplicate_timepoints > 0)


  if (length(err_validation) > 0) {
    stop_custom(
      .subclass = "invalid_data",
      message = paste0(
        "Invalid data or column names supplied.\n",
        paste(err_validation, collapse = "\n")
      )
    )
  }

}
