# Contributing

We use GitHub to manage reviews of pull requests.

If you're planning to do a large amount of work, such as a new sample app, you should discuss your
ideas in a new issue. This will help you avoid unnecessary work and surely give you and us a good
deal of inspiration.

For trivial fixes or improvements, pull requests can be opened immediately without an issue.

## Before Contributing

- Read [what a sample app needs to run in CI](../sample-apps/README.md), and run your sample app
  locally as described in the [README](../README.md).
- Sign our CLA otherwise we're not able to accept contributions.
- If you use generative AI tools, you must review our [Generative AI Contribution Policy](./genai.md).

### Signed commits

All Grafana Labs repositories [require signed commits](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-signed-commits).
To learn how to enable commit verification, refer to [about commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification) and refer to this page to learn about [checking your commit signature verification status](https://docs.github.com/en/authentication/troubleshooting-commit-signature-verification/checking-your-commit-and-tag-signature-verification-status).

**NOTE** Unsigned commits and pull requests will be rejected and closed. This includes pull requests that have been authored by Agents.

## Steps to Contribute

Should you wish to work on an issue, please claim it first by commenting on the GitHub issue that
you want to work on it. This is to prevent duplicated efforts from contributors on the same issue.

If you have questions about an issue, please comment on it and one of the maintainers will clarify
it.

## Pull Request Checklist

Changes should be branched off of the `main` branch. It's recommended to rebase on top of `main`
before submitting the pull request to fix any merge conflicts that may have appeared during
development.

CI starts each sample app your PR changes and checks that it produces the metrics in its
`tests/metrics/` lists. A sample app CI can't run needs a `.CI_BYPASS` file; test it by hand and say
how in the PR.

Never commit credentials, real endpoints or stack URLs. Rendered `cloud-init.yaml` files and
`jinja/variables/` hold your real values, so check `git status` before committing.

Smaller PRs are more likely to be reviewed faster and easier to validate for correctness; consider
splitting up your work across multiple PRs if making a significant contribution.

If your PR is not getting reviewed or you need a specific person to review it, you can @-reply a
reviewer asking for a review in the pull request or a comment, or you can ask for a review on the
Slack channel [#integrations](https://slack.grafana.com).

## Pull request titles and commit messages

Pull requests are squash merged, so the PR title becomes the commit message on `main`.

PR titles should:

1. Read as a complete sentence in the imperative, present tense (e.g. "Add", not "Adds" or
   "Added").
2. Start with an uppercase letter.
3. Name the sample app the change is for, if there is one.
4. Describe the effect of the change. Default to being explicit over vague.

For example: `Add a replication slot to the PostgreSQL sample app`

> - Vague: `Fix metrics`
> - Explicit: `Fix postgres sample app expected metrics list`

Dependency update PRs from Renovate use Conventional Commit titles, e.g.
`chore(deps): update ...`. You don't need to.

## Dependency management

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date, configured in
[.github/renovate.json](../.github/renovate.json). It groups updates by sample app directory, runs
before 3am on Mondays (Europe/Amsterdam), and waits 3 days after a release before proposing it.

When you add or change a dependency yourself:

- Pin it to a version, or a digest for container images, so Renovate can update it.
- Use the dependency's official source. A fork must be temporary, with an upstream change opened to
  remove the need for it.
