# 9 - Videos

# Understanding dbt State and Retry

- Learn about state management in dbt and how it enhances efficiency.
- Learn how to efficiently rebuild your data pipelines with the dbt retry command.

dbt’s **state** feature lets you compare the current project against a prior run (typically production), enabling “partial” or “slim” builds. When you run a dbt command with a `--state` path, dbt reads a saved **manifest.json** (and related artifacts) from that directory and uses it to identify which models are *new*, *modified*, or *unchanged*. The manifest is a snapshot of the project’s schema and configurations (every model, test, etc.) at the time of the previous run. In essence, “state” represents the project’s last known state ([Understanding dbt Cloud jobs with state:modified | by Trang Trinh | Medium](https://medium.com/@hongtrang251/understanding-dbt-cloud-jobs-with-state-modified-c4fc0944f69c#:~:text=,with%20most%20of%20their%20properties)) ([Continuous integration in dbt Cloud | dbt Developer Hub](https://docs.getdbt.com/docs/deploy/continuous-integration#:~:text=production,tests%29%20directly)). Using state is useful in CI or feature-branch workflows: dbt can **compare** your feature branch against production, run only changed models (and their dependents), and reuse the existing results for the rest.

## State selectors (`state:*`)

dbt provides special selector methods based on state comparison. For example:

- `state:new` selects any resource (model, test, etc.) **new** in the current project (it has no counterpart in the comparison manifest).
- `state:modified` selects all **new or changed** resources. In detail, a model is considered modified if anything changed in its SQL (body), its config (e.g. materialization, tags, meta), its database/schema/alias (`relation`), its documented descriptions (if `persist_docs` is on), or upstream macros/contracts ([Node selector methods | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/methods#:~:text=,in%20the%20comparison%20manifest)) ([Understanding dbt Cloud jobs with state:modified | by Trang Trinh | Medium](https://medium.com/@hongtrang251/understanding-dbt-cloud-jobs-with-state-modified-c4fc0944f69c#:~:text=,excluding%20the%20changes%20in%20the)).
- Conversely, `state:old` matches any resource that exists in both states, and `state:unmodified` matches resources with **no changes** ([Node selector methods | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/methods#:~:text=There%20are%20two%20additional%20,the%20inverse%20of%20those%20functions)).

For example, if you run:

```bash
dbt run --select state:modified --state path/to/prod/artifacts
```

dbt will build only the models that have been added or changed since the saved production artifacts. In general, state selectors only work in conjunction with `--state <path>` (or the `DBT_STATE` environment variable) pointing to a directory containing the prior run’s `manifest.json` (and usually `run_results.json`) ([Node selector methods | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/methods#:~:text=,in%20the%20comparison%20manifest)) ([Node selector methods | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/methods#:~:text=,after)). By default, dbt’s node ref resolution still uses the current target; you must add `--defer` (see below) to redirect refs to the state manifest as needed.

Note that when using state selection, you should **preserve** the old manifest so it isn’t overwritten. For instance, if you run production builds writing to `target/`, copy or move `target/manifest.json` into a separate `state/` folder before your next run. Otherwise dbt may overwrite the manifest and lose the comparison baseline ([Node selector methods | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/methods#:~:text=,after)).

### The `--state` flag

To use state-based selection, add `--state <path>` to your dbt commands. For example:

```
dbt run --select state:modified+ --defer --state path/to/prod/artifacts

```

Here `path/to/prod/artifacts` should contain the production run artifacts (typically `manifest.json` and `run_results.json` from the latest successful prod run). The `state:modified+` selector means “all modified nodes plus their children” (the `+` operator adds downstream dependencies). In practice, you often combine state filters with others, e.g.:

```
dbt test --select result:fail --defer --state prod_manifest/

```

to rerun only the tests that failed previously (ignoring those still passing) ([Best practices for workflows | dbt Developer Hub](https://docs.getdbt.com/best-practices/best-practice-workflows#:~:text=dbt%20test%20,state%20path%2Fto%2Fprod%2Fartifacts)).

You can also use `dbt ls --select` with state filters to *list* which models would be selected. For example:

```
dbt ls --select state:modified+ --state prod_artifacts/

```

will list all models marked new or changed since the production run ([Syntax overview | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/syntax#about-node-selection#:~:text=dbt%20ls%20,result%20statuses%20and%20are%20modified)).

Internally, dbt reads the manifest JSON at the `--state` location and compares each node to the current project’s nodes ([Node selector methods | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/methods#:~:text=,in%20the%20comparison%20manifest)). It then categorizes them as new, modified (and *why*), or unchanged. (The full criteria are detailed in the docs, but common changes include modified SQL, configs, or upstream macros ([Understanding dbt Cloud jobs with state:modified | by Trang Trinh | Medium](https://medium.com/@hongtrang251/understanding-dbt-cloud-jobs-with-state-modified-c4fc0944f69c#:~:text=,excluding%20the%20changes%20in%20the)).) Using state filters can dramatically **speed up CI builds** by skipping unchanged work.

### Slim CI / Partial Builds

The combination of state-based selectors and `--defer` enables **Slim CI** – CI pipelines that build *only changed models*instead of the entire project. In this workflow, the production CI (CD) job first runs a full build and uploads its artifacts (e.g. `manifest.json` and `run_results.json`) to storage ([Slim CI/CD with Bitbucket Pipelines for dbt Core | dbt Developer Blog](https://docs.getdbt.com/blog/slim-ci-cd-with-bitbucket-pipelines#:~:text=connections%2C%20then%20running%20what%20needs,or%20another%20file%20storage%20service)) ([Slim CI/CD with Bitbucket Pipelines for dbt Core | dbt Developer Blog](https://docs.getdbt.com/blog/slim-ci-cd-with-bitbucket-pipelines#:~:text=database%20reflects%20the%20dbt%20transformation%2C,resulting%20artifacts%20to%20defer%20to)). Then the PR or CI job **downloads those artifacts** and runs dbt with state comparison. For example, a Bitbucket Pipeline could do:

```yaml
- step: "Upload artifacts"
  script:
    - dbt run --target prod  # full prod build
    - curl ... upload target/manifest.json to artifact store

- step: "CI build for PR"
  script:
    - curl ... download manifest.json into state/
    - export DBT_FLAGS="--defer --state state/ --select +state:modified"
    - dbt run $DBT_FLAGS
    - dbt test $DBT_FLAGS

```

In this Slim CI step, using `--state state/` with `--select state:modified+` tells dbt to rebuild only the changed models and their dependents, reusing the prod artifacts for everything else. In other words, **unchanged upstream models are “deferred” to prod**, so only new code is executed. A recent dbt blog explains: “dbt artifacts are metadata of the last run – what models and tests were defined, which ones ran successfully, and which failed. If a future dbt run is set to defer to this metadata, it can select models and tests to run based on their state, especially their difference from the reference metadata.” ([Slim CI/CD with Bitbucket Pipelines for dbt Core | dbt Developer Blog](https://docs.getdbt.com/blog/slim-ci-cd-with-bitbucket-pipelines#:~:text=,difference%20from%20the%20reference%20metadata)).

As a result, CI becomes much faster and cheaper. (The term *partial build* is also used: you build a partial DAG, and defer the rest to production.) Note that dbt Cloud’s built-in CI uses the same idea: it tracks the state of production and only runs changed assets in a PR, as shown here: “dbt Cloud tracks the state of what’s running in your production environment so, when you run a CI job, only the modified data assets in your pull request … and their downstream dependencies are built and tested in a staging schema.” ([Continuous integration in dbt Cloud | dbt Developer Hub](https://docs.getdbt.com/docs/deploy/continuous-integration#:~:text=production,tests%29%20directly)).

### Deferring Upstream Models with `-defer`

The `--defer` flag is crucial to Slim CI and sandbox testing. It tells dbt that for *any non-selected model that’s not already in your dev database*, dbt should resolve its `ref()` to the version in the state manifest (typically production). In practice, you use `--defer --state <path>` together. For example, suppose you are working on `model_C` which depends on `model_B -> model_A`. In your development schema, only `model_C` will be built, and `model_A/B` are missing. Without deferral, dbt would error out. But with `--defer`, dbt will generate `model_C` using the production versions of `model_A` and `model_B`.

([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer)) *The diagram above* illustrates this. The top (red) approach (“Don’t do this”) tries to build `model_C` and its upstreams in dev without deferral, and it fails because `model_A/B` aren’t present. The bottom (green) approach uses `dbt build -s model_C --defer --state path/to/artifacts`. Here dbt “defers” the references: any ref to `model_A` or `model_B` is resolved to the production objects, so `model_C` can build against them. In other words, by passing the production manifest via `--state` and `--defer`, dbt automatically points ref calls to the already-built prod tables when needed ([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer#:~:text=When%20%60,manifest%20instead%2C%20but%20only%20if)) ([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer#:~:text=Defer%20requires%20that%20a%20manifest,Read%20more%20about%20state)).

Under the hood, **deferral rules are** (from the docs) ([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer#:~:text=When%20%60,manifest%20instead%2C%20but%20only%20if)): if a node is *not* among the selected nodes, and it isn’t found in the database, then dbt resolves its `ref` to the version in the state manifest instead of in the target schema. Ephemeral models are never deferred (they always run in the current graph) ([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer#:~:text=When%20%60,manifest%20instead%2C%20but%20only%20if)). You must supply both `--defer` and `--state` (or set the `DBT_DEFER` and `DBT_STATE` env vars) for this to work ([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer#:~:text=Deferral%20requires%20both%20%60,to%20set%20up%20CI%20jobs)).

Together, state selection and deferral let you effectively “fail over” missing upstream models to prod. This saves time because you don’t rebuild everything, and it makes feature-branch testing practical in large projects.

## The `dbt retry` Command

The `dbt retry` CLI command (introduced in dbt v1.6) lets you **resume a failed run from the point of failure**. It inspects the last `run_results.json` to see which nodes were already successfully built, and then reruns the remaining ones. In effect, it re-executes the previous dbt command using the same selection arguments but starting at the failure point ([About dbt retry command | dbt Developer Hub](https://docs.getdbt.com/reference/commands/retry#:~:text=%60dbt%20retry%60%20re,the%20node%20point%20of%20failure)) ([About dbt retry command | dbt Developer Hub](https://docs.getdbt.com/reference/commands/retry#:~:text=,failures%20will%20garner%20idempotent%20results)). If the previous run finished successfully, `dbt retry` does nothing (“no operation”). If the initial run failed before any nodes ran (for example, a pre-run connection error), then `dbt retry` also has nothing to do (it won’t rerun *from the beginning* in that case) ([About dbt retry command | dbt Developer Hub](https://docs.getdbt.com/reference/commands/retry#:~:text=%60dbt%20retry%60%20re,the%20node%20point%20of%20failure)). The docs advise: if no nodes executed, check the error and manually rerun, since there’s no recorded checkpoint to resume from ([About dbt retry command | dbt Developer Hub](https://docs.getdbt.com/reference/commands/retry#:~:text=%60dbt%20retry%60%20re,the%20node%20point%20of%20failure)).

The `dbt retry` command works with most dbt commands that produce a `run_results.json`, including `dbt run`, `dbt build`, `dbt test`, `dbt compile`, `dbt seed`, and others ([About dbt retry command | dbt Developer Hub](https://docs.getdbt.com/reference/commands/retry#:~:text=Retry%20works%20with%20the%20following,commands)). It uses the same selectors as before, so it only runs the nodes that were attempted previously. For example, if `dbt run --select foo+`failed halfway through, `dbt retry` will run again from the failure in `foo` downward. If you haven’t fixed the error, the retry will typically fail immediately on the same model (and quickly exit) ([About dbt retry command | dbt Developer Hub](https://docs.getdbt.com/reference/commands/retry#:~:text=,failures%20will%20garner%20idempotent%20results)). Once the error is fixed, `dbt retry` will continue and complete the build. (If you rerun `dbt run` from the beginning instead, it would re-execute all earlier models too; `dbt retry` skips those.)

In **dbt Cloud jobs**, similar functionality is provided via the UI. If a scheduled or manual run fails, the job’s Run History page shows a **“Rerun”** button. From there you can choose “Rerun from start” or “Rerun from failure” ([Retry your dbt jobs | dbt Developer Hub](https://docs.getdbt.com/docs/deploy/retry-jobs#:~:text=If%20your%20dbt%20job%20run,of%20failure%20in%20dbt%20Cloud)). Selecting “Rerun from failure” will resume the job at the failed step: the job UI displays a modal listing the failed (and skipped) steps, and after confirmation it re-executes them. A banner then appears on the Run Summary stating “This run resumed execution from last failed step” ([Retry your dbt jobs | dbt Developer Hub](https://docs.getdbt.com/docs/deploy/retry-jobs#:~:text=If%20you%20chose%20to%20rerun,This%20run%20resumed)). In other words, dbt Cloud provides an experience analogous to `dbt retry`.

### Retry Policies in dbt Cloud

In addition to manual reruns, dbt Cloud allows you to configure **automatic retry policies** for jobs. In a job’s **Advanced Settings**, you can set the number of retry attempts (and sometimes a delay between attempts). When enabled, if a job run fails (for example, due to a transient network or warehouse hiccup), dbt Cloud will automatically re-run the job up to the specified number of times. This is useful to recover from temporary errors without manual intervention. (For example, setting 2 retries will cause an errored run to be retried up to two more times.) While the exact UI labels may change, look for “Retry attempts” or “Failure” settings when editing a job in dbt Cloud. If you use orchestration tools (Airflow, etc.), those tools have their own retry configurations as well. In any case, both the manual “Rerun” button and the job retry policy rely on the same underlying dbt retry mechanism.

## Examples

- **State-based run:** To build only models changed since the last production run, you might run:
    
    ```bash
    dbt run --select state:modified+ --defer --state prod_artifacts/
    dbt test --select state:modified+ --defer --state prod_artifacts/
    
    ```
    
    Here `prod_artifacts/` contains the last prod `manifest.json`. This command compares the current code to production, runs all modified models (+ dependencies) in dev, and uses the prod tables for unchanged upstream models ([Best practices for workflows | dbt Developer Hub](https://docs.getdbt.com/best-practices/best-practice-workflows#:~:text=By%20comparing%20to%20artifacts%20from,of%20of%20their%20unmodified%20parents)).
    
- **Selecting new models:** To test only brand-new models (added since prod), use:
    
    ```bash
    dbt list --select state:new --state prod_artifacts/
    
    ```
    
    This lists models present now that weren’t in the previous manifest. You could similarly run `dbt test --select state:new --state prod_artifacts/` to test just those.
    
- **Deferred run example:** Suppose `model_b` depends on `model_a`, and only `model_a` exists in production. In development, running `dbt run --select model_b` will error (dev database has no `model_a`). But if you have the prod `manifest.json` saved (e.g. in `prod-run-artifacts/`), you do:
    
    ```bash
    dbt run --select model_b --defer --state prod-run-artifacts/
    
    ```
    
    Now dbt will build `model_b` and resolve `ref('model_a')` to the production `prod.model_a`, allowing the run to succeed ([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer#:~:text=,run)) ([Defer | dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/defer#:~:text=dbt%20run%20,artifacts)). (The deferred output effectively changes the SQL to select from the prod schema.)
    
- **Retry example:** Imagine a run fails on `customers` due to a syntax error. After fixing it, instead of rerunning the entire DAG, run:
    
    ```bash
    dbt retry
    
    ```
    
    The CLI will resume at `customers` and finish the remaining models/tests. If using dbt Cloud, you could also click **Rerun from failure** on the job page to accomplish the same.
    

## Questions

**1. What is the main purpose of using the `--state` flag in dbt?**

A) To cache compiled SQL files

B) To compare the current project with a previous state

C) To increase run speed by disabling tests

D) To rebuild all models from scratch

---

**2. Which command would correctly run only models with SQL body changes compared to a previous run?**

A) `dbt run --select state:modified+ --defer`

B)  `dbt run --state path/to/previous/run_artifacts -s state:modified.body`

C) `dbt run --defer --select modified.state+`

D) `dbt run --select "body:modified+" --defer --state artifacts/`

---

**3. What does `--defer` do during a dbt run?**

A) It deletes outdated models.

B) It compiles models without running them.

C) It allows using existing built models when referenced models are not selected.

D) It prevents documentation generation during builds.

---

**4. In Slim CI, where should the `+` symbol be placed when using `state:modified`?**

A) Before `state`

B) After `state:modified`

C) Before and after `modified`

D) It doesn’t matter

---

**5. Which sub-selector would you use if you only want to trigger builds when a model's configuration (e.g., materialization) changes?**

A) `state:modified.body`

B) `state:modified.configs`

C) `state:modified.contract`

D) `state:modified.relation`

---

**6. Which file does `dbt retry` use to determine which models failed?**

A) `manifest.json`

B) `dbt_project.yml`

C) `run_results.json`

D) `profiles.yml`

---

**7. Which of the following dbt commands is NOT supported by `dbt retry`?**

A) `dbt build`

B) `dbt test`

C) `dbt docs generate`

D) `dbt init`

---

**8. You want to rerun only failed models from a previous production job. The failed run artifacts are stored in `prod_run/`. Which command is correct?**

A) `dbt build --state prod_run/`

B) `dbt retry --retry-path prod_run/run_results.json`

C) `dbt run --retry prod_run/`

D) `dbt retry --state prod_run`

---

**9. Which combination of flags would you most likely use in a Slim CI workflow?**

A) `--select "state:modified+" --defer --state previous_artifacts/`

B) `--defer --state modified/ --select "state:configs+"`

C) `--select "state:modified.body+" --compile-only`

D) `--retry-path previous_artifacts/ --defer`

---

# **dbt Mesh Introduction**

Learn which dbt mesh topics are essential for the Analytics Engineer Certification Exam.

# **dbt Clone**

Discover how dbt clone empowers developers to effortlessly create database object copies for testing and development without duplicating data.

# **Grants**

Unlock the full potential of dbt with grants, enabling precise control over permissions for models, seeds, and snapshots in your projects.

# **Python Models**

dbt Python models can help you solve use cases that can't be solved with SQL. You can perform analyses using tools available in the open-source Python ecosystem, including state-of-the-art packages for data science and statistics.