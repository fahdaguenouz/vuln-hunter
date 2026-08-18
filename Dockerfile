# ============================================================
# VulnHunter — OWASP Juice Shop Docker Setup (v20 Compatible)
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
# INFRASTRUCTURE VULNERABILITY NOTE:
#   Pinned to a specific v20.x release to ensure reproducible builds 
#   and mitigate the supply-chain risks of using the 'latest' tag.
FROM bkimminich/juice-shop:v20.2.0

# --- Metadata ---
LABEL maintainer="VulnHunter Security Research"
LABEL description="OWASP Juice Shop — intentionally vulnerable web app for security training"
LABEL version="2.0"
LABEL project="VulnHunter"

# --- Expose application port ---
# Juice Shop listens on port 3000 by default.
# INFRASTRUCTURE VULNERABILITY NOTE (RESOLVED):
#   In previous versions, the app ran as root. As of v20+, the image natively 
#   utilizes a distroless environment and runs as a non-root user (USER 65532), 
#   successfully fulfilling the principle of least privilege out of the box.
EXPOSE 3000

# Note: The custom CMD and HEALTHCHECK overrides have been removed as they 
# rely on shell utilities (like wget) which do not exist in the modern 
# distroless base image used in v20+.