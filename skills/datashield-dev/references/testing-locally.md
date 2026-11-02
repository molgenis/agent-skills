# Running tests locally

Run a package's client-side tests on all three backends before calling a change green:

- **DSLite**: the server runs inside your R session. No Docker and fast, but it differs from a
  real server in the ways listed below.
- **Armadillo in Docker**: the same setup dsBaseClient's CI uses (on Apple Silicon, see the end of
  this page).
- **Opal in Docker**: as dsBaseClient's CI does, on a different port so it can run beside Armadillo.

Keep these in mind for any backend:

- **Match dsBase to the client branch, not just the major version.** A client refactor branch
  usually needs the dsBase branch with the same name. With the wrong build, most tests fail with
  signature or class errors that say nothing about the mismatch. Check with `git grep` on the dsBase
  ref, and confirm the installed version on the server.
- **Run the full suite before calling a change green.** Changing a function also breaks other test
  files that call it in their setup. Run the changed files first because they are quick.
- **Don't stop early.** testthat stops after 10 failures by default and still prints a summary that
  looks complete. Set `Sys.setenv(TESTTHAT_MAX_FAILS = "999999")`, or use
  `ProgressReporter$new(max_failures = 999999)` as CI does.
- **See the server's reason for a failure.** "There are some DataSHIELD errors" hides it. Reproduce
  the single call and print `DSI::datashield.errors()`.
- **Leave out `perf-` tests locally.** Their reference rates are calibrated to CI, so a pass or fail
  on a laptop means nothing. CI sets `PERF_PROFILE=github-workflows`.
- **Use CI's filters.** Files for dsBase and files for dsDanger are separate: the `_dgr-` files need
  dsDanger on the server. The dsBase filter is
  `_-|datachk-|smk-|arg-|disc-|smk_expt-|expt-|math-`, and the dsDanger filter is
  `__dgr-|datachk_dgr-|smk_dgr-|arg_dgr-|disc_dgr-|smk_expt_dgr-|expt_dgr-|math_dgr-`.

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

4. Upload the test data. A fresh server is empty, and without the data every test fails at login
   with `table datashield/cnsim/CNSIM1 is not accessible`. The script uses relative paths, so run
   it from its own directory:

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

To install dsDanger for the `_dgr-` files, build it from tag `6.3.4` and install it the same way
as dsBase, then whitelist it. The tag's package version is 6.3.1.

### Apple Silicon

Amd64 R images fail under Docker's emulation: every package install stops with "Does not appear to
be an R package (no DESCRIPTION)" (<https://github.com/datashield/docker-rock/issues/25>).
`datashield/rock-base` now has an arm64 build, but `datashield/rock_citest-permissive`, which the
compose file above uses, is still amd64-only, so step 5 fails with it.

Use a `default` profile on `datashield/rock-base:latest` instead:

1. Run Armadillo with `scripts/benchmark/run_local_armadillo.sh` from molgenis-service-armadillo.
2. Check the profile's image is `datashield/rock-base:latest`, pull it, and recreate the profile.
   Recreating removes packages installed in it. Confirm with `docker exec default uname -m`, which
   should print `aarch64`.

   ```bash
   docker pull datashield/rock-base:latest
   curl -s -u admin:admin -X POST http://localhost:8080/ds-profiles/default/start
   ```

   Newer Armadillo versions serve this at `/containers/default/start`.

3. `rock-base` isn't permissive, so before step 5 above set
   `default.datashield.privacyControlLevel="permissive"` in a copy of dsBase's `inst/DATASHIELD`,
   and build the tarball from that copy.

## Opal in Docker

Armadillo holds port 8080, so use the compose file in molgenis-service-armadillo, which serves Opal
on 8081 and 8443. The test harness connects on 8443. `datashield/opal_citest` is amd64-only and runs
fine under emulation; its R server is `rock-base`, which is native on arm64.

1. Start the servers, with the Opal version from dsBaseClient's `docker-compose_opal.yml`. On arm64,
   first run `docker pull --platform linux/amd64 datashield/opal_citest:<version>` and add
   `--pull never`.

   ```bash
   OPAL_VERSION=<version> docker compose -p opal -f scripts/benchmark/opal/docker-compose.yml up -d
   ```

2. Wait until Opal stays up. It restarts itself during its first boot, so a first successful login
   doesn't mean it's ready: an install during this time ends in "Empty reply from server". Wait for
   about a minute of consecutive 200s from `http://localhost:8081/`.
3. Upload the test data from the dsBaseClient checkout:

   ```bash
   cd tests/testthat/data_files && Rscript obiba_opal-upload_testing_datasets.R
   ```

4. Enable package administration, which is otherwise refused with 403, then install dsBase from
   GitHub and make the profile permissive. `dsadmin.install_local_package` can return without error
   and leave the old version in place, so always check the version afterwards.

   ```r
   library(opalr)
   opal <- opal.login("administrator", "datashield_test&", url = "http://localhost:8081/")
   opal.put(opal, "system", "conf", "general", "_rPackage")
   dsadmin.install_github_package(opal, "dsBase", username = "datashield", ref = "v7.0-dev")
   dsadmin.profile_init(opal, name = "default", packages = c("dsBase", "resourcer"))
   dsadmin.set_option(opal, "default.datashield.privacyControlLevel", "permissive")
   dsadmin.package_description(opal, "dsBase")$Version
   opal.logout(opal)
   ```

   For the `_dgr-` files, also install dsDanger with `ref = "6.3.4"` and add it to `packages`.

5. Run the tests as for Armadillo, with `default_driver = "OpalDriver"`. First write `localhost` to
   `tests/testthat/connection_to_datasets/local_settings.csv` (gitignored), which holds the bare
   host, not a URL.

If Opal fails at startup with an OrientDB error, its stored data is corrupt. Remove the stack with
`docker compose -p opal -f scripts/benchmark/opal/docker-compose.yml down -v` and start again, which
deletes everything stored in that Opal.

## Ports

CI's `docker-compose_opal.yml` serves Opal on 8080, the port Armadillo needs, so don't run it beside
Armadillo. Installing against the wrong port silently targets the other server. Check first:
`curl -s -u admin:admin localhost:<port>/actuator/info` returns `molgenis-armadillo` build details
from Armadillo and a 404 from Opal.

## After a server restart

A restart or a recreated container can lose packages installed at runtime and, on a released jar,
uploaded data. Check the dsBase version and the tables again before trusting a run.

## Working on Armadillo itself

These run from a molgenis-service-armadillo checkout:

- **From source:** `SERVER_PORT=8080 ./gradlew run`. Run `./gradlew --stop` first if an earlier
  daemon ran with different permissions. Health check: `curl -fsS http://localhost:8080/actuator/health`.
- **Release tests:** copy `scripts/release/dev.env.dist` to `.env` and fill it in, install
  dependencies once with `./install_release_script_dependencies.R`, then run `./release-test.R` from
  `scripts/release`. With `OIDC_EMAIL` empty it runs in admin mode, as CI does, which skips the
  resource tests.
- **Storage API:** with basic auth, `PUT /access/projects` creates a project,
  `POST /storage/projects/{project}/csv` uploads a CSV (`file`, `object`,
  `numberOfRowsToDetermineTypeBy`) and `POST /storage/projects/{project}/objects` uploads parquet
  (`file`, `object`).
