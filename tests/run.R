source('cohort.R')
users <- read.csv('fixtures/users.csv', colClasses='character')
events <- read.csv('fixtures/events.csv', colClasses='character')
checks <- 0L
check <- function(condition) { stopifnot(isTRUE(condition)); checks <<- checks + 1L }
fails <- function(expression) { check(inherits(tryCatch({force(expression); NULL}, error=function(e) e), 'error')) }
result <- retention(users, events, '2026-04-15', 3L)
jan <- result[result$cohort == '2026-01', ]
check(identical(jan$cohort_size, rep(2L,4)))
check(identical(jan$active_users, c(2L,1L,1L,NA_integer_)))
check(identical(jan$retention, c(1,0.5,0.5,NA_real_)))
check(identical(jan$observable, c(TRUE,TRUE,TRUE,FALSE)))
check(is.na(jan$denominator[4]))
check(!'2026-05' %in% result$cohort)
feb <- result[result$cohort == '2026-02', ]
check(feb$active_users[2] == 0L && feb$retention[2] == 0)
complete <- retention(users, events, '2026-04-30', 3L)
check(complete$retention[complete$cohort == '2026-01' & complete$month == 3L] == 0.5)
check(nrow(retention(users, events, '2025-12-31', 3L)) == 0L)
fails(retention(rbind(users, users[1,]), events, '2026-04-15'))
bad <- events; bad$user_id[1] <- 'unknown'
fails(retention(users, bad, '2026-04-15'))
bad <- events; bad$activity_date[1] <- '2025-12-31'
fails(retention(users, bad, '2026-04-15'))
fails(retention(users, events, '2026-02-30'))
fails(retention(users, events, '2026-04-15', 1.5))
leap_users <- data.frame(user_id='x', signup_date='2024-02-01')
leap_events <- data.frame(user_id='x', activity_date='2024-02-29')
check(!retention(leap_users, leap_events, '2024-02-28', 0L)$observable)
check(retention(leap_users, leap_events, '2024-02-29', 0L)$retention == 1)
empty_events <- data.frame(user_id=character(), activity_date=character())
check(retention(leap_users, empty_events, '2024-02-29', 0L)$retention == 0)
cat(sprintf('PASS: %d cohort assertions\n', checks))
