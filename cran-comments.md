## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* macOS (local), R 4.5.2
* win-builder (devel)
* win-builder (release)

## Downstream dependencies

This is a new package with no downstream dependencies.

## Notes to CRAN reviewers

* This package requires internet access to query the City of Winnipeg 
  Open Data Portal (data.winnipeg.ca). All live API tests use 
  `skip_on_cran()` and `skip_if_offline()`.
* The OData V4 endpoint used is publicly available with no 
  authentication required.