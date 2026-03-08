## R CMD check results

0 errors | 0 warnings | 1 note

## Notes

* New submission
* "OData" and "Socrata" are flagged as possibly misspelled — these are 
  intentional technical terms (OData is an ISO standard, Socrata is the 
  data portal platform). Both are now quoted in DESCRIPTION.
* Broken Socrata documentation URL has been replaced with the main 
  developer portal URL.

## Test environments

* macOS (local), R 4.5.2
* win-builder R release: 1 NOTE (new submission + spelling)
* win-builder R devel: pending

## Downstream dependencies

This is a new package with no downstream dependencies.

## Notes to CRAN reviewers

* This package requires internet access to query the City of Winnipeg
  Open Data Portal (data.winnipeg.ca). All live API tests use
  `skip_on_cran()` and `skip_if_offline()`.
* The OData V4 endpoint used is publicly available with no
  authentication required.