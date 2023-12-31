
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tinduck

The tinduck package generates interactive html reports that enable quick
visual review of multiple related time series. This can help with
identification of any temporal artefacts or unexpected trends. The
resulting reports are shareable and can contribute to forming a
transparent record of the entire analysis process.

The supplied data frame should contain multiple time series in long
format, i.e.: \* one “timepoint” (datetime) column which will be used
for the x-axes. This currently must be at a daily granularity, but
values do not have to be consecutive. \* one “item” (character) column
containing categorical values identifying distinct time series. \* one
“value” (numeric) column containing the time series values which will be
used for the y-axes. \* Optionally, a “group” (character) column
containing categorical values which will be used to group the time
series into different tabs on the report. The `colspec` parameter maps
the data frame columns to the above.

It currently expects only time series with daily values, and missing
timepoints are allowed.

The resulting html report displays each time series in a row in a table,
with tooltips showing the individual dates and values.

These reports are shareable and can contribute to forming a transparent
record of the entire analysis process. It is designed with electronic
health records in mind, but can be used for any types of time series.

## Installation

``` r
# install direct from source
# install.packages("remotes")
remotes::install_github("phuongquan/tinduck")
```

## Usage

``` r
library(tinduck)

# the example dataset contains 3 columns: timepoint, item, value
data("example_data")

head(example_data)
```

    ##    timepoint      item value
    ## 1 2022-01-01      norm   111
    ## 2 2022-01-01 norm_step    47
    ## 3 2022-01-01      zero     0
    ## 4 2022-01-01        na    NA
    ## 5 2022-01-01 zero_norm     0
    ## 6 2022-01-01   na_norm    NA

``` r
# create a report in the current directory
tinduck_report(df = example_data,
               colspec = list(timepoint_col = "timepoint",
                              item_col = "item",
                              value_col = "value")
               )
```

## Acknowledgements

This work was supported by the National Institute for Health Research
Health Protection Research Unit (NIHR HPRU) in Healthcare Associated
Infections and Antimicrobial Resistance at the University of Oxford in
partnership with Public Health England (PHE) (NIHR200915), and by the
NIHR Oxford Biomedical Research Centre.

## Contributing to this package

Please report any bugs or suggestions by opening a [github
issue](https://github.com/phuongquan/tinduck/issues).
