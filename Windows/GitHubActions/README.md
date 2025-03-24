# BuildKit GitHub Actions Example

[Docker is pinned to v24.0.7](https://github.com/actions/runner-images/issues/9478) on GitHub Actions hosted Windows runners, so containerd and BuildKit need to be installed manually.

This [workflow file](./install_buildkit_workflow.yaml) can be used as an example.
