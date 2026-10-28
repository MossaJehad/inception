# Contributing

Thanks for taking the time to improve this project. The maintainer is `mhasoneh`.
Read the [code of conduct](CODE_OF_CONDUCT.md) before participating.

## Project scope

The repository currently contains a directory scaffold and documentation only.
Discuss substantial runtime changes before implementing them. Mandatory subject
requirements take priority over bonus features; community documents do not change
the assignment requirements.

This is a 42 learning project. Contributions should help the learner understand
the work, and participation must respect the academic rules that apply to you.

## Reporting issues

Use the bug report or feature request template. Include a clear description,
reproduction steps where applicable, expected behavior, and relevant environment
details. Distinguish a defect from a feature that has not been implemented yet.
Check [the roadmap](docs/ROADMAP.md) before reporting missing functionality.

For sensitive findings, follow [SECURITY.md](SECURITY.md) instead of posting details
in a public issue. Remove credentials, private paths, and tokens from shared logs.

## Making a change

1. Work on a focused branch in your own checkout or fork.
2. Preserve existing content unless the change requires editing it.
3. Keep service sources under `srcs/requirements/` and required docs at the root.
4. Explain the problem, the resulting behavior, and any material tradeoffs.
5. Update affected documentation and the unreleased changelog when appropriate.
6. Open a pull request using the provided template.

Use readable Markdown and descriptive file names. Match nearby conventions. Avoid
unrelated formatting changes, generated artifacts, and adding secrets or runtime
data. Provide sanitized examples instead of real credentials.

## Validation

Documentation-only changes need accurate links and descriptions. No test suite
or CI pipeline is configured yet; do not claim checks that were not run.
When runtime code is added, include the relevant build, configuration, service,
security, and persistence checks in its pull request.

Review the diff and new files before submitting. `.gitignore` cannot remove a
secret already present in Git history. If a secret was exposed, revoke or rotate
it and follow [the security policy](SECURITY.md).

## Attribution and licensing

Submit only work you are entitled to contribute. Original contributions are
provided under the repository's [MIT License](LICENSE). Retain applicable
third-party notices and clearly attribute borrowed material. The 42 subject and
third-party software keep their own terms.
