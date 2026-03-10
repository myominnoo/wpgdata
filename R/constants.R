# =============================================================================
# constants.R
# =============================================================================

.SOCRATA_URL <- "https://api.us.socrata.com/api/catalog/v1"
.WINNIPEG_URL <- "https://data.winnipeg.ca"
.TIMEOUT_SECS <- 30L
.MAX_RETRIES <- 3L
.MAX_CONNECTIONS <- 20L # ceiling for auto-detected parallel connections
.PAGE_SIZE <- 1000L # Socrata OData API max rows per request
