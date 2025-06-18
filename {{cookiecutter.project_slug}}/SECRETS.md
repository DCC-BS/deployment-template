# GitHub Repository Secrets Configuration

This document describes the secrets that need to be configured in your GitHub repository for the CI/CD workflows to work properly.

## Required Secrets

### GitHub Container Registry (GHCR)
- **GITHUB_TOKEN**: Automatically provided by GitHub Actions
  - Used for: Pushing to ghcr.io, creating releases, committing changes
  - Permissions: Contents: write, Packages: write

## Optional Registry Secrets

### Linkyard Container Registry
If you want to push to Linkyard's container registry, configure these secrets:
- **LINKYARD_CONTAINER_REGISTRY_USER**: Your Linkyard registry username
- **LINKYARD_CONTAINER_REGISTRY_PASSWORD**: Your Linkyard registry password

### Quay.io Container Registry  
If you want to push to Quay.io, configure these secrets:
- **QUAY_CONTAINER_REGISTRY_USER**: Your Quay.io username
- **QUAY_CONTAINER_REGISTRY_PASSWORD**: Your Quay.io password/token

## How to Configure Secrets

1. Go to your GitHub repository
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add each secret with the exact name listed above

## Registry Configuration

The workflows are configured to:
- **Always use GHCR** (GitHub Container Registry) when `ghcr-enabled: true`
- **Optionally use Linkyard** when `linkyard-enabled: true` and credentials are provided
- **Optionally use Quay.io** when `quay-enabled: true` and credentials are provided

## Example Secret Values

```bash
# For Linkyard (example)
LINKYARD_CONTAINER_REGISTRY_USER=your-username
LINKYARD_CONTAINER_REGISTRY_PASSWORD=your-secure-password

# For Quay.io (example)  
QUAY_CONTAINER_REGISTRY_USER=your-quay-username
QUAY_CONTAINER_REGISTRY_PASSWORD=your-quay-token
```

## Security Notes

- Never commit actual secret values to your repository
- Use strong, unique passwords for registry access
- Consider using registry tokens instead of passwords where possible
- Regularly rotate your credentials
- The test-build workflow does not require registry credentials as it doesn't push images

## Troubleshooting

- If deployment fails with authentication errors, verify your secrets are correctly named and have valid values
- Check that your registry credentials have push permissions
- Ensure the GITHUB_TOKEN has sufficient permissions (this is usually automatic)
