## Resubmission

This is a resubmission. Please ignore the previous submission of v0.1.0 
and consider this v0.2.0 submission instead. The previous submission has 
not yet been reviewed.

Changes in v0.2.0:
* Added `peg_catalogue()` to list all available datasets from the portal
* Fixed trailing slash in package URL in DESCRIPTION
* Added `rlang::.data` import to resolve R CMD check note

## R CMD check results

0 errors | 0 warnings | 1 note

## Notes

* New submission
* "OData" and "Socrata" are intentional technical terms —
  'OData' is an ISO/IEC approved standard, 'Socrata' is the
  data portal platform powering data.winnipeg.ca.
  Both are quoted in DESCRIPTION.

## Test environments

* macOS (local), R 4.5.2 — 0 errors | 0 warnings | 0 notes
* win-builder R release  — 1 note (new submission only)
* win-builder R devel    — 1 note (new submission only)

## Downstream dependencies

This is a new package with no downstream dependencies.

## Notes to CRAN reviewers

* This package requires internet access to query the City of Winnipeg
  Open Data Portal (data.winnipeg.ca). All live API tests use
  `skip_on_cran()` and `skip_if_offline()`.
* The OData V4 endpoint is publicly available with no authentication
  required.