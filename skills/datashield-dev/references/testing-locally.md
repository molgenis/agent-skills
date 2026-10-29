# Running tests locally

Two ways to run a package's client-side tests against a server:

- **DSLite**: the server runs inside your R session. No Docker, works on every platform, fast.
  It differs from a real server in the ways listed below.
- **Armadillo in Docker**: the same setup dsBaseClient's CI uses. Closer to production, but
  installing server packages fails on Apple Silicon (see the end of this page).

Use DSLite for day-to-day work and let CI cover Opal and Armadillo, unless the bug only appears on
a real server.

## DSLite: how it differs from a real server

- **Each session's workspace is its own environment, not `.GlobalEnv`.** A server function that
  finds objects through `.GlobalEnv`, or through `eval(parse(text = ...))` without an `envir`,
  works on Opal and Armadillo but breaks under DSLite. It may fail with an odd error (a data
  symbol such as `D` or `df` resolving to `stats::D` or `stats::df`), or it may silently use an
  object with the same name in the client's session. Look objects up in the caller's
  environment (`parent.frame()`, or dsBase's internal `.loadServersideObject()`), and pass
  `envir = parent.frame()` to any `eval()`.
- **Listing the workspace.** `lsDS` lists `.GlobalEnv`, which under DSLite is the client's own
  session. To see a DSLite session's objects use `DSI::datashield.symbols(conns)`.
- **Privacy level.** DSLite takes the default from the package's `DATASHIELD` file, which may be
  stricter than a test server. To match servers configured as permissive, set it on the DSLite
  server before logging in:

  ```r
  dslite.server$option("default.datashield.privacyControlLevel", deparse("permissive"))
  ```

- **Error messages.** Opal and Armadillo prefix server errors with `* Error : `; DSLite does not.
  Tests that match error text need a pattern that works for both.

Catch the environment problem in server-side unit tests: create the test data inside
`test_that()`, not in the global environment, and call the server function there. A function
that only looks in `.GlobalEnv` then fails in the test, not in a user's DSLite session.

## DSLite (dsBaseClient's suite)

Run from a dsBaseClient checkout. DSLite is the suite's default driver. `tests/testthat/setup.R`
loads DSLite, DSOpal, DSMolgenisArmadillo, lme4, e1071 and DescTools whichever driver you use, so
install them all.

The server side is whichever dsBase is installed in your R library: the test servers load it
from there. To test a particular dsBase, install it first (`R CMD INSTALL path/to/dsBase`, or into
a separate library that you put first with `.libPaths()`).

```r
devtools::load_all()
options(default_driver = "DSLiteDriver", datashield.return_errors = FALSE)
testthat::test_dir("tests/testthat", filter = "smk-ds.dim", stop_on_failure = FALSE)
```

Expect each file's `setup` and `shutdown` tests to fail once per server under DSLite, with
"Only in `actual`: connect.all.datasets ...". Those checks list the workspace with `lsDS`, which
sees the client's session (see above). Judge the result by the other tests in the file.

## Armadillo in Docker (dsBaseClient's CI setup)

Run from a dsBaseClient checkout. It needs Docker, R with MolgenisArmadillo and DSMolgenisArmadillo,
and a free port 8080: the upload script and the test harness both assume it, so stop whatever
holds it rather than changing the port. The compose file starts Armadillo plus one fixed
permissive R profile (`default`), so there are no profiles to manage.

1. Check Docker is running: `docker info`. If it fails, start Docker first.
2. Start the servers. The images are amd64-only; on an arm64 machine prefix the command with
   `DOCKER_DEFAULT_PLATFORM=linux/amd64`.

   ```bash
   docker compose -f docker-compose_armadillo.yml up -d
   ```

3. Wait until healthy (usually under a minute):

   ```bash
   for i in $(seq 1 60); do
     curl -fsS http://localhost:8080/actuator/health | grep -q '"status":"UP"' && break
     sleep 5
   done
   ```

4. Upload the test data. The script uses relative paths, so run it from its own directory:

   ```bash
   cd tests/testthat/data_files && Rscript molgenis_armadillo-upload_testing_datasets.R
   ```

5. Build and install the dsBase version you want to test, then check the version and whitelist it.
   The install can fail while the R profile is still starting; retry after a few seconds.

   ```bash
   R CMD build path/to/dsBase
   curl -s -u admin:admin -F "file=@dsBase_<version>.tar.gz" http://localhost:8080/install-package
   curl -s -u admin:admin http://localhost:8080/packages
   curl -s -u admin:admin -X POST http://localhost:8080/whitelist/dsBase
   ```

6. Run tests, failing files first and the full suite last:

   ```r
   devtools::load_all()
   options(default_driver = "ArmadilloDriver", datashield.return_errors = FALSE)
   testthat::test_dir("tests/testthat", filter = "smk-ds.glm", stop_on_failure = FALSE)
   ```

7. Stop: `docker compose -f docker-compose_armadillo.yml down`.

The CI equivalents are `.github/actions/setup-armadillo-with-dsbase/action.yaml` and
`.github/workflows/dsBaseClient_test_suite.yaml` in dsBaseClient.

### Apple Silicon

The R profile images (`datashield/rock-base`, `datashield/rock_citest-permissive`) are amd64-only
and based on Ubuntu 26.04. Under Docker's amd64 emulation (Rosetta or QEMU) their `tar` fails with
"Function not implemented", so every package install fails with "Does not appear to be an R package
(no DESCRIPTION)". This affects Opal as well, because it uses the same images. Steps 1-4 work;
step 5 does not. Use DSLite on these machines. Tracked in
<https://github.com/datashield/docker-rock/issues/25>.
