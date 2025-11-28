# Reusable GitHub Workflows

This directory contains reusable GitHub Actions workflows that can be called by other workflows.

## `reusable-slack-notify.yml`

This workflow sends a Slack notification about the status of a build and deployment pipeline. It constructs a message indicating success or failure and sends it to a specified Slack channel.

### How it Works

The workflow is triggered by a `workflow_call` event. It determines the message and color of the Slack notification based on the `build_result` and `deploy_result` inputs.

-   If `build_result` is `failure`, it sends a build failure notification.
-   If `deploy_result` is `success`, it sends a deployment success notification.
-   Otherwise, it sends a deployment failure notification.

### Usage

To use this workflow, call it from another workflow using the `uses` keyword. You must provide the required inputs and secrets.

**Example from a calling workflow:**

```yaml
jobs:
  slack-notification:
    if: always() # Ensure this job runs even if previous jobs fail
    needs: [build-and-push, deploy]
    uses: Addvocate-ai/reusable-github-workflows/.github/workflows/reusable-slack-notify.yml@main
    with:
      project_name: 'my-cool-app'
      image_tag: ${{ needs.build-and-push.outputs.tags }}
      environment: ${{ needs.deploy.outputs.environment }}
      build_result: ${{ needs.build-and-push.result }}
      deploy_result: ${{ needs.deploy.result }}
      run_id: ${{ github.run_id }}
      repository: ${{ github.repository }}
      actor: ${{ github.actor }}
      server_url: ${{ github.server_url }}
    secrets:
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Inputs

The workflow requires the following inputs:

| Input           | Required | Description                                                  | Default |
| --------------- | :------: | ------------------------------------------------------------ | ------- |
| `project_name`  |   Yes    | The name of the project being deployed.                      |         |
| `image_tag`     |   Yes    | The tag of the Docker image that was built.                  |         |
| `environment`   |    No    | The deployment environment (e.g., `Staging`, `Production`).  | `N/A`   |
| `build_result`  |   Yes    | The result of the build job (e.g., `success`, `failure`).    |         |
| `deploy_result` |   Yes    | The result of the deployment job (e.g., `success`, `failure`). |         |
| `run_id`        |   Yes    | The ID of the workflow run, used to create a link.           |         |
| `repository`    |   Yes    | The name of the repository where the workflow was triggered. |         |
| `actor`         |   Yes    | The GitHub user who triggered the workflow.                  |         |
| `server_url`    |   Yes    | The URL of the GitHub server.                                |         |

### Secrets

The workflow requires the following secret:

| Secret                | Required | Description                                           |
| --------------------- | :------: | ----------------------------------------------------- |
| `SLACK_WEBHOOK_URL`   |   Yes    | The incoming webhook URL for your Slack workspace.    |
