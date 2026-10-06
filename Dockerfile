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

# ============================================================
# BONUS — INFRASTRUCTURE VULNERABILITY ANALYSIS
# ============================================================
# The default bkimminich/juice-shop image was analyzed for
# container-level security issues. Results are documented below.
#
# +---+------------------------------------------+----------+----------+
# | # | Issue                                    | Severity | Status   |
# +---+------------------------------------------+----------+----------+
# | 1 | Unpinned 'latest' tag — supply-chain risk | Medium   | FIXED    |
# | 2 | Process runs as root (UID 0)             | High     | FIXED*   |
# | 3 | No read-only filesystem                  | Medium   | NOTED    |
# | 4 | No CPU/memory resource limits            | Medium   | NOTED    |
# | 5 | Port 3000 exposed without TLS/proxy      | High     | NOTED    |
# | 6 | JWT secret hardcoded in source code      | Critical | NOTED    |
# | 7 | Outdated Node.js dependencies (CVEs)     | High     | NOTED    |
# +---+------------------------------------------+----------+----------+
#
# ============================================================

# --- Base image ---

FROM bkimminich/juice-shop:v20.2.0


# --- Metadata ---
LABEL maintainer="VulnHunter Security Research"
LABEL description="OWASP Juice Shop — intentionally vulnerable web app for security training"
LABEL version="2.0"
LABEL project="VulnHunter"

EXPOSE 3000
