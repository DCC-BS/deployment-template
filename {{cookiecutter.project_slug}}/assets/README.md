# Certificate Assets

This directory contains certificate files that will be installed into Docker images when the `_needs_certs` flag is set to `true` for an image in the `deploy.config` file.

## Usage

1. Place your certificate files (`.crt`, `.pem`, etc.) in this directory
2. Configure the image to need certificates in `deploy.config` by setting `{image_name}_needs_certs=true`
3. Set the certificate installation path in `deploy.config` with `cert_install_path` (default: `/usr/local/share/ca-certificates`)

## Certificate Installation Process

When an image is flagged as needing certificates:

1. The image is built normally using the Dockerfile
2. All certificate files from this directory are copied into the image at the specified path
3. The `update-ca-certificates` command is run to install the certificates (for Debian/Ubuntu based images)
4. The modified image is tagged and pushed to the registry

## Supported Certificate Formats

- `.crt` - Certificate files
- `.pem` - PEM encoded certificates
- `.cer` - Certificate files

## Example Files

Place your certificate files here:
```
assets/
├── company-root-ca.crt
├── intermediate-ca.pem
└── custom-cert.crt
```

All files in this directory will be copied to the Docker image when certificate installation is enabled. 