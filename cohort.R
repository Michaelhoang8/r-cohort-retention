# Base-R monthly activity retention with explicit right-censoring.
strict_dates <- function(value, label) {
  if (!is.character(value) || anyNA(value) || any(!grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', value))) stop(paste(label, 'must use YYYY-MM-DD'))
  result <- as.Date(value, format='%Y-%m-%d')
  if (anyNA(result) || any(format(result, '%Y-%m-%d') != value)) stop(paste(label, 'contains an invalid date'))
  result
}

month_index <- function(date) as.integer(format(date, '%Y')) * 12L + as.integer(format(date, '%m')) - 1L
month_start <- function(index) as.Date(sprintf('%04d-%02d-01', index %/% 12L, index %% 12L + 1L))

retention <- function(users, events, as_of, months=6L) {
  if (!is.data.frame(users) || !identical(names(users), c('user_id','signup_date'))) stop('users columns must be user_id,signup_date')
  if (!is.data.frame(events) || !identical(names(events), c('user_id','activity_date'))) stop('events columns must be user_id,activity_date')
  if (length(as_of) != 1L) stop('as_of must be one date')
  cutoff <- strict_dates(as_of, 'as_of')
  if (length(months) != 1L || !is.numeric(months) || is.na(months) || months != floor(months) || months < 0L || months > 120L) stop('months must be an integer from 0 to 120')
  for (frame in list(users, events)) {
    if (!is.character(frame$user_id) || anyNA(frame$user_id) || any(trimws(frame$user_id) == '')) stop('user_id must be nonempty text')
  }
  if (anyDuplicated(users$user_id)) stop('duplicate user_id in users')
  signup <- strict_dates(users$signup_date, 'signup_date')
  activity <- strict_dates(events$activity_date, 'activity_date')
  owner <- match(events$user_id, users$user_id)
  if (anyNA(owner)) stop('event user_id absent from users')
  if (any(activity < signup[owner])) stop('activity precedes signup')
  included <- signup <= cutoff
  cohorts <- month_index(signup)
  event_months <- month_index(activity)
  available <- activity <= cutoff & included[owner]
  rows <- list()
  for (cohort in sort(unique(cohorts[included]))) {
    members <- users$user_id[included & cohorts == cohort]
    for (age in 0:months) {
      period <- cohort + age
      observed <- month_start(period + 1L) - 1L <= cutoff
      active <- if (observed) length(unique(events$user_id[available & event_months == period & events$user_id %in% members])) else NA_integer_
      rows[[length(rows)+1L]] <- data.frame(cohort=format(month_start(cohort), '%Y-%m'), month=age,
        cohort_size=length(members), period=format(month_start(period), '%Y-%m'), observable=observed,
        active_users=active, denominator=if (observed) length(members) else NA_integer_,
        retention=if (observed) active / length(members) else NA_real_)
    }
  }
  if (!length(rows)) return(data.frame(cohort=character(),month=integer(),cohort_size=integer(),period=character(),observable=logical(),active_users=integer(),denominator=integer(),retention=double()))
  do.call(rbind, rows)
}

main <- function(args) {
  if ('--help' %in% args) {
    cat('Usage: Rscript cohort.R --users USERS.csv --events EVENTS.csv --as-of YYYY-MM-DD [--months 6]\nWrites retention CSV to stdout. Only complete calendar months are observable.\n')
    return(0L)
  }
  tryCatch({
    if (length(args) %% 2L != 0L) stop('options require values; use --help')
    options <- list()
    if (length(args)) for (i in seq.int(1L, length(args), by=2L)) {
      key <- args[i]
      if (!key %in% c('--users','--events','--as-of','--months') || key %in% names(options)) stop('unknown or duplicate option')
      options[[key]] <- args[i+1L]
    }
    if (!all(c('--users','--events','--as-of') %in% names(options))) stop('users, events and as-of are required')
    read_input <- function(path) read.csv(path, colClasses='character', check.names=FALSE, stringsAsFactors=FALSE)
    months <- if ('--months' %in% names(options)) suppressWarnings(as.numeric(options[['--months']])) else 6L
    result <- retention(read_input(options[['--users']]), read_input(options[['--events']]), options[['--as-of']], months)
    write.csv(result, stdout(), row.names=FALSE, na='')
    0L
  }, error=function(error) { cat(conditionMessage(error), '\n', file=stderr()); 2L })
}

if (sys.nframe() == 0L) quit(status=main(commandArgs(trailingOnly=TRUE)))
