# Monthly Cohort Retention

A base-R analysis that groups signups into calendar-month cohorts and measures the fraction active in later months. It distinguishes observed zero activity from periods that are still incomplete at the reporting cutoff.

```sh
Rscript cohort.R --help
Rscript cohort.R --users fixtures/users.csv --events fixtures/events.csv --as-of 2026-04-15 --months 3
Rscript tests/run.R
```

Requires R 4.1 or later; no packages. The CSV fixtures are authored examples with fictional user IDs. The January cohort has two users: retention is 100% in January, 50% in February and 50% in March. April is blank at the April 15 cutoff, even though an April activity is present.

Input schemas are `user_id,signup_date` and `user_id,activity_date`, with ISO `YYYY-MM-DD` dates. User IDs must be unique in the signup table. Events with unknown IDs, invalid dates or activity before signup are rejected. Multiple activities by the same user in a month count once. Signups and events after the cutoff are excluded from the reported population, after validation.

The denominator is the complete cohort size, not the number of users who produced events. A cell is observable only after its calendar month's last day. An observable month without activity is zero; a partial or future month has blank numerator, denominator and retention. `cohort_size` remains available for context. Cohort month zero measures actual activity and is not forced to 100%. Month offsets use calendar months, including leap years, rather than 30-day durations.

`--months` is the maximum offset, inclusive, from 0 through 120. CSV goes to stdout; diagnostics go to stderr. Success exits 0 and validation errors exit 2. Empty eligible populations produce headers only.

This is bounded, in-memory descriptive analysis. It does not estimate survival probabilities, infer missing events, handle account merges or adjust for acquisition-channel differences. Results assume the supplied events are complete through the cutoff. A more recent signup cohort remains censored until its signup month closes, preventing premature comparison with complete cohorts.

Local R execution was unavailable on the authoring host. The repository includes a native R CI job and 17 assertions; successful execution must be confirmed from that job before claiming validation.
