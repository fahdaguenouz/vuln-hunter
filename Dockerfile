# ============================================================
# VulnHunter — OWASP Juice Shop Docker Setup
# ============================================================
# PURPOSE:
#   Runs the intentionally vulnerable OWASP Juice Shop web app
#   for ethical hacking & vulnerability research in a sandboxed
#   environment.
#
# ⚠️  SECURITY NOTICE:
#   This image is INTENTIONALLY VULNERABLE. Never expose it to
#   a public network or production environment.
# ============================================================

# --- Base image ---
# Using the official Juice Shop image from Docker Hub.
# INFRASTRUCTURE VULNERABILITY NOTE:
#   Using 'latest' tag is a security anti-pattern in production —
#   it prevents reproducible builds and may silently introduce
#   breaking or insecure changes. In a hardened setup, pin to a
#   specific digest (e.g., bkimminich/juice-shop@sha256:<digest>).
FROM bkimminich/juice-shop:latest

# --- Metadata ---
LABEL maintainer="VulnHunter Security Research"
LABEL description="OWASP Juice Shop — intentionally vulnerable web app for security training"
LABEL version="1.0"
LABEL project="VulnHunter"

# --- Expose application port ---
# Juice Shop listens on port 3000 by default.
# INFRASTRUCTURE VULNERABILITY NOTE:
#   The app runs as root inside the container (upstream image default),
#   which violates the principle of least privilege. In a hardened
#   environment you would add:
#       RUN addgroup -S juiceshop && adduser -S juiceshop -G juiceshop
#       USER juiceshop
#   However, changing the user here may conflict with the upstream
#   image's startup scripts, so it is left as-is for this lab.
EXPOSE 3000

# --- Health check ---
# Verifies the application is responding before marking the
# container healthy. Useful when composing services.
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget -qO- http://localhost:3000 || exit 1

# --- Start application ---
# The upstream image already defines CMD/ENTRYPOINT; this is kept
# explicit for clarity and auditability.
CMD ["node", "/juice-shop/build/app.js"]
