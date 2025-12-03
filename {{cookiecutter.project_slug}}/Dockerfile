ARG TAG

FROM {{cookiecutter.docker_image_name}}:${TAG}

# Switch to root for installation actions
USER root

COPY assets/*.crt /usr/local/share/ca-certificates/

RUN if command -v apk > /dev/null; then \
    apk update && apk add --no-cache ca-certificates; \
    elif command -v apt-get > /dev/null; then \
    apt-get update && apt-get install -y ca-certificates; \
    fi && \
    chmod 644 /usr/local/share/ca-certificates/*.crt && \
    update-ca-certificates

# Argument for the Original User (passed from workflow)
ARG ORIGINAL_USER
# Switch back to the original user
USER ${ORIGINAL_USER}