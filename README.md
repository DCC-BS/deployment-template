# Deployment Template

A cookiecutter template for creating a Docker image with SSL certificates.


## Quick Start


1. **Create a new deployment repository**:
```uvx cookiecutter https://github.com/dcc-bs/deployment-template.git
```

3. **Configure your deployment**:
   - Repository URLs for your projects
   - Docker image name

## Certificate Installation

One of the key features of this template is automatic certificate installation into Docker images. This is useful when your applications need to trust custom Certificate Authorities or internal certificates.

#
### Configuration

Certificate installation is configured during template creation:

```json
{
    "project_slug": "my-deployment",
    "docker_image_name": "ghcr.io/my-org/my-image"
}
```

### Certificate Files

Place your certificate files in the `assets/` directory:

```
assets/
├── company-root-ca.crt
└── custom-cert.crt
```

Supported formats: `.crt`

## Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_slug` | Name of the deployment project | `my-app-deployment` |
| `docker_image_name` | Name of the Docker image | `ghcr.io/my-org/my-image` |

## Supported Base Images

Certificate installation works with:
- **Debian/Ubuntu**: Uses `apt-get` and `update-ca-certificates`
- **Alpine Linux**: Uses `apk` and `update-ca-certificates`

## License

This template is released under the MIT License.
