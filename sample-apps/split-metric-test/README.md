# [EXAMPLE] Split metric test sample-app

This example sample-app is a clone of the [Linux sample-app](../linux-node/), with support for split metrics tests, allowing for subsets of metrics to be tested with individual configs, e.g. to support additional specific selectors, job labels, or other similar reasons to split.

To use split metric testing, follow these steps:
1. Ensure no `.CI_BYPASS` file is present
2. Ensure **no .config** file is present
3. Create a new directories `tests/configs/` and `tests/metrics/`
4. Create expected metric files in `tests/metrics/` naming them whatever you desire, but leaving no file-type. e.g. `linux_1`, `linux_2`, and `linux_3`
   These files should be a simple newline separated list of metrics
5. Create matching config files in `tests/configs/` matching the name, but using the `.config` file type, resulting in e.g. `linux_1.config`, etc. 
   These files should each contain:
   a) `JOB_LABEL` as in existing configs
   b) `EXTRA_GREP_REGEX` if you wish to grep the resultant metrics for more specifics, this is appended to the existing job label check
   c) `METRICS_SUCCESS_RATE_REQUIRED` (optional, if you need < 80% pass rate)
