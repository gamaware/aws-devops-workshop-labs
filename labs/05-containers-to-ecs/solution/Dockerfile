# Harbor Goods catalog API. Standard library only, so there is nothing to install.
# The base image is pinned by digest: the same bytes every build, updated by Dependabot.
FROM python:3.14-slim@sha256:51dafde81dbdb6ebde285137a295cf18a47ca95234fe388a343719cb97305b3d

# No .pyc files (the root filesystem is read-only on ECS) and unbuffered logs.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# The app needs no package manager at run time. Removing pip (and the libraries it
# vendors) leaves less for a scanner to report and for an attacker to use.
RUN python -m pip uninstall --yes --root-user-action=ignore pip

WORKDIR /app
COPY app/server.py app/products.json ./

# A numeric, unprivileged user. ECS and Kubernetes can then verify it is not root.
USER 10001:10001

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --start-interval=2s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)"]

# Exec form: python is PID 1 and receives SIGTERM directly.
CMD ["python", "server.py"]
