# 🔍 VulnHunter — OWASP Juice Shop Vulnerability Research

<div align="center">

![OWASP](https://img.shields.io/badge/OWASP-Top%2010-red?style=for-the-badge&logo=owasp)
![Docker](https://img.shields.io/badge/Docker-Ready-blue?style=for-the-badge&logo=docker)
![Security](https://img.shields.io/badge/Purpose-Ethical%20Hacking-green?style=for-the-badge&logo=hackthebox)
![Status](https://img.shields.io/badge/Status-Research%20Lab-orange?style=for-the-badge)

> **Penetration Testing Report** — Vulnerabilities identified, exploited, and documented in the OWASP Juice Shop intentionally vulnerable web application.

</div>

---

## ⚠️ Legal Disclaimer

> This project is for **educational purposes only**. All testing was performed exclusively on the intentionally vulnerable OWASP Juice Shop running locally in an isolated Docker container. No unauthorized systems were targeted. The techniques documented here must only be used with **explicit written permission** from system owners.

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Setup & Installation](#setup--installation)
3. [Infrastructure Vulnerability Analysis](#infrastructure-vulnerability-analysis)
4. [Exploit Reports](#exploit-reports)
   - [1. SQL Injection (SQLi)](#1-sql-injection-sqli)
   - [2. Cross-Site Scripting (XSS)](#2-cross-site-scripting-xss)
   - [3. Broken Authentication](#3-broken-authentication)
   - [4. Insecure Direct Object Reference (IDOR)](#4-insecure-direct-object-reference-idor)
   - [5. Security Misconfiguration — Exposed Admin Panel](#5-security-misconfiguration--exposed-admin-panel)
   - [6. Broken Access Control — Admin Basket Manipulation ⭐ Bonus](#6-broken-access-control--admin-basket-manipulation--bonus)
5. [Ethical Hacking Report](#ethical-hacking-report)
6. [Automated Scanning with OWASP ZAP](#automated-scanning-with-owasp-zap)
7. [Resources](#resources)

---

## Project Overview

| Field             | Details                                |
|-------------------|----------------------------------------|
| **Target**        | OWASP Juice Shop                       |
| **Environment**   | Local Docker container (isolated)      |
| **Scope**         | `http://localhost:3000`                |
| **Methodology**   | OWASP Testing Guide v4, PTES           |
| **Vulnerabilities Found** | 6 (5 mandatory + 1 bonus)     |
| **OWASP ZAP Scan**| ✅ Performed                          |
| **Dockerfile Analysis** | ✅ Performed                    |

---

## Setup & Installation

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- Port `3000` available on localhost

### Option 1 — Quick Start (Docker Hub)

```bash
docker pull bkimminich/juice-shop
docker run --rm -p 3000:3000 bkimminich/juice-shop
```

### Option 2 — Using This Repository's Dockerfile

```bash
# Clone the repository
git clone https://github.com/fahdaguenouz/vuln-hunter.git
cd vuln-hunter

# Build and run
docker build -t vuln-hunter-lab .
docker run --rm -p 3000:3000 vuln-hunter-lab
```

### Access the Application

Open your browser and navigate to:

```
http://localhost:3000
```

> **Tip**: Use Firefox with the **FoxyProxy** extension alongside **Burp Suite** (or **OWASP ZAP**) as an intercepting proxy on `127.0.0.1:8080` for full request manipulation.

---

## Infrastructure Vulnerability Analysis

> This section addresses the **Bonus objective** — analyzing the Dockerfile and container setup for infrastructure-level security issues.

The OWASP Juice Shop Docker image (v20) was analyzed for infrastructure vulnerabilities:

| # | Issue | Severity | CWE |
|---|-------|----------|-----|
| 1 | **Unpinned `latest` tag** — No reproducibility; supply-chain risk | Medium | CWE-829 |
| 2 | **Process runs as root** — Container process has UID 0 (Resolved in v20+) | High | CWE-250 |
| 3 | **No read-only filesystem** — Container FS is writable | Medium | CWE-732 |
| 4 | **No resource limits** — No CPU/memory caps (DoS risk) | Medium | CWE-400 |
| 5 | **Port 3000 directly exposed** — No reverse proxy or TLS | High | CWE-319 |
| 6 | **No secrets management** — JWT secret hardcoded in source | Critical | CWE-798 |
| 7 | **Outdated Node.js dependencies** — npm audit reports known CVEs | High | CWE-1035 |

### Recommended Hardening (Dockerfile)

```dockerfile
# Pin to a specific image digest or version tag for reproducibility
FROM bkimminich/juice-shop:v20.2.0

# As of v20+, the image natively utilizes a distroless environment 
# and runs as a non-root user (USER 65532). No need to manually add groups/users.
# (Previous versions required manual privilege dropping)

# Use a reverse proxy (nginx) with TLS termination in production
# Set resource limits at the docker run / compose level:
# --memory="512m" --cpus="1.0"
# Mount the filesystem read-only where possible:
# --read-only --tmpfs /tmp
```

---

## Exploit Reports

---

### 1. SQL Injection (SQLi)

**OWASP Category**: A03:2021 — Injection  
**Severity**: 🔴 Critical  
**CWE**: CWE-89

#### Description

SQL Injection occurs when user-supplied input is embedded directly into a SQL query without sanitization, allowing an attacker to alter query logic.

#### How It Was Exploited

The login form at `http://localhost:3000/#/login` was targeted.

**Step 1** — Open the login page and launch an intercepting proxy (Burp Suite / ZAP).

**Step 2** — Enter the following payload in the **Email** field:

```
' OR 1=1--
```

**Step 3** — Enter any value in the **Password** field and submit.

**Step 4** — The application logs in as the **admin** user (first record in the `Users` table) without requiring valid credentials.

**Proof of Concept (HTTP Request)**:

```http
POST /rest/user/login HTTP/1.1
Host: localhost:3000
Content-Type: application/json

{"email":"' OR 1=1--","password":"anything"}
```

**Response**: HTTP 200 with a valid JWT token for the admin account.

#### Root Cause

The backend constructs the SQL query by string concatenation:
```sql
SELECT * FROM Users WHERE email = '<input>' AND password = '<hash>'
```
The `' OR 1=1--` payload closes the email string, adds a always-true condition, and comments out the rest of the query.

#### Impact

- Complete authentication bypass
- Access to all user accounts (admin escalation)
- Potential for data exfiltration, modification, and deletion across the entire database

#### Remediation

1. **Use parameterized queries / prepared statements** — Never concatenate user input into SQL strings.
2. **Use an ORM** (e.g., Sequelize) with proper query binding.
3. **Input validation** — Reject inputs containing SQL metacharacters where not expected.
4. **Least privilege** — The database user should have only SELECT rights on necessary tables.
5. **WAF** — Deploy a Web Application Firewall to detect and block common SQLi patterns.

---

### 2. Cross-Site Scripting (XSS)

**OWASP Category**: A03:2021 — Injection  
**Severity**: 🟠 High  
**CWE**: CWE-79

#### Description

XSS allows attackers to inject client-side scripts into web pages viewed by other users. Juice Shop is vulnerable to both **Reflected** and **DOM-based** XSS.

#### How It Was Exploited

**DOM-based XSS — Search Field**

**Step 1** — Navigate to the search bar at `http://localhost:3000/#/search?q=`.

**Step 2** — Enter the following payload and press Enter:

```html
<iframe src="javascript:alert('XSS')">
```

**Step 3** — The browser executes the script and renders an alert popup, confirming script execution in the victim's browser context. Angular processes the URL parameter and renders it without proper sanitization.

**DOM-based XSS — Track Order Page**

**Step 1** — Navigate to:

```
http://localhost:3000/#/track-result?id=<script>alert('DOM-XSS')</script>
```

**Step 2** — The page reads the `id` parameter from the URL and renders it without sanitization into the DOM, triggering script execution.

#### Impact

- **Session hijacking** — Steal `document.cookie` / `localStorage` tokens
- **Credential phishing** — Inject fake login forms
- **Malware distribution** — Redirect users to attacker-controlled pages
- **CSRF amplification** — Perform actions on behalf of authenticated users

#### Remediation

1. **Output encoding** — HTML-encode all user-supplied data before rendering (use libraries like DOMPurify).
2. **Content Security Policy (CSP)** — Add a strict `Content-Security-Policy` header to block inline scripts.
3. **HttpOnly & Secure cookie flags** — Prevent JavaScript access to session cookies.
4. **Angular / React built-in escaping** — Avoid using `[innerHTML]` or `dangerouslySetInnerHTML` with user data.

---

### 3. Broken Authentication

**OWASP Category**: A07:2021 — Identification and Authentication Failures  
**Severity**: 🟠 High  
**CWE**: CWE-287

#### Description

Juice Shop exposes a weak password reset mechanism that allows account takeover without knowing the victim's original password.

#### How It Was Exploited

**Scenario**: Taking over the admin account via the "Forgot Password" flow.

**Step 1** — Navigate to `http://localhost:3000/#/forgot-password`.

**Step 2** — Enter the admin's known email: `admin@juice-sh.op`

**Step 3** — The security question is revealed: *"Mother's maiden name?"*
**source code questions** -`https://raw.githubusercontent.com/juice-shop/juice-shop/v20.0.0/data/static/securityQuestions.yml`
**source code** -`https://raw.githubusercontent.com/juice-shop/juice-shop/v20.0.0/data/static/users.yml`

**Step 4** — The answer (`@xI98PxDO+06!`) is embedded in the Juice Shop source code / challenge hints. Enter it.

**Step 5** — Set a new password and log in as admin.


#### Impact
- Full account takeover of any user (including admin)
- Bypass of all access controls
- Data theft and privilege escalation

#### Remediation

1. **Rate-limit password reset requests** — Prevent brute-force enumeration.
2. **Use cryptographically strong JWT secrets** — Minimum 256-bit random secret; store in a secrets manager (e.g., HashiCorp Vault).
3. **JWT expiry** — Enforce short-lived tokens with proper refresh token rotation.

---

### 4. Insecure Direct Object Reference (IDOR)

**OWASP Category**: A01:2021 — Broken Access Control  
**Severity**: 🟠 High  
**CWE**: CWE-639

#### Description

IDOR occurs when an application exposes internal object references (e.g., database IDs) in URLs or API parameters without verifying the requesting user has authorization to access that object.

#### How It Was Exploited

**Scenario**: Accessing another user's shopping basket.

**Step 1** — Log in as a regular user (e.g., `jim@juice-sh.op`).

**search for security quetions** - `https://en.wikipedia.org/wiki/James_T._Kirk`
```
Samuel
```
**Step 2** — Add an item to your basket. Intercept the request:

```http
GET /rest/basket/2 HTTP/1.1
Authorization: Bearer <your_jwt>
```

**Step 3** — Change the basket ID from `2` to `1` (the admin's basket):

```http
GET /rest/basket/1 HTTP/1.1
Authorization: Bearer <your_jwt>
```

**Step 4** — The server returns the admin's basket contents without any authorization check.

#### Impact

- Access to private data of any user (orders, personal information, payment details)
- Ability to modify or delete other users' resources

#### Remediation

1. **Server-side authorization checks** — Verify that the authenticated user owns the requested resource on every request.
2. **Indirect references** — Use non-guessable, user-specific tokens (UUIDs) instead of sequential integer IDs.
3. **Access control unit tests** — Test every API endpoint with tokens belonging to different users.

---

### 5. Security Misconfiguration — Exposed Admin Panel

**OWASP Category**: A05:2021 — Security Misconfiguration  
**Severity**: 🟠 High  
**CWE**: CWE-200

#### Description

The Juice Shop administration panel is accessible via a guessable URL without network-level restrictions.

#### How It Was Exploited

**Step 1** — Without any prior knowledge, run a directory brute-force scan:

```bash
gobuster dir -u http://localhost:3000 \
  -w /usr/share/wordlists/dirb/common.txt \
  -t 50 --quiet
```

**Step 2** — Output reveals: `/#/administration`

**Step 3** — Navigate to `http://localhost:3000/#/administration`.

**Step 4** — While a login is required to fully access it, the endpoint is fully discoverable. Combining this with the SQLi admin login yields full admin panel access: user listing, feedback management, order management.

#### Impact

- Enumeration of all registered users and their email addresses
- Mass deletion of user feedback (integrity impact)
- Platform management by unauthorized parties

#### Remediation

1. **Network-level restriction** — Restrict admin routes to internal IP ranges or VPN.
2. **Separate admin interface** — Run the admin portal on a different port/domain not reachable from the public internet.
3. **Multi-factor authentication** — Require MFA for any administrative action.
4. **Security headers** — Apply `X-Robots-Tag: noindex` and remove admin routes from `sitemap.xml`.

---

### 6. Broken Access Control — Admin Basket Manipulation ⭐ Bonus

**OWASP Category**: A01:2021 — Broken Access Control  
**Severity**: 🔴 Critical  
**CWE**: CWE-285

#### Description

A logged-in user can place orders on behalf of other users and manipulate quantities, because the API trusts the user-supplied basket ID in the request body.

#### How It Was Exploited

**Step 1** — Log in as a regular user. Add an item to your cart and intercept the checkout API call:

```http
POST /api/BasketItems HTTP/1.1
Content-Type: application/json
Authorization: Bearer <user_jwt>

{"ProductId":1,"BasketId":"2","quantity":1}
```

**Step 2** — Change `"BasketId"` to `"1"` (admin's basket) and resend.

**Step 3** — The item is added to the admin's cart — confirmed by logging in as admin.

#### Impact

- Fraudulent orders placed against victim accounts
- Price manipulation (setting `quantity` to `0` or negative values to receive discounts)
- Denial of service against specific user accounts

#### Remediation

1. **Derive basket ID from the authenticated session** — Never accept `BasketId` from user-supplied request body.
2. **Authorization middleware** — Validate resource ownership at the API gateway or middleware layer.

---

## Ethical Hacking Report

### Overview

This report documents the ethical responsibilities, legal considerations, and professional standards followed throughout the VulnHunter project.

---

### 1. Authorization and Scope

> **The most fundamental principle of ethical hacking: never test what you do not have explicit permission to test.**

For this project:

- All testing was performed **exclusively** on the OWASP Juice Shop running locally in an isolated Docker container (`http://localhost:3000`).
- The OWASP Juice Shop is a **purposely vulnerable application** created specifically for security training — it comes with **implicit authorization** for security testing.
- No live, production, or third-party systems were ever targeted.
- The scope was strictly limited to the local network interface (`127.0.0.1`).

**In a professional engagement**, authorization would be established via:
- A signed **Rules of Engagement (RoE)** document
- A written **Penetration Testing Agreement**
- Clearly defined **scope boundaries** (IP ranges, domains, application components)
- An agreed **testing window** to minimize business disruption

---

### 2. Legal and Ethical Boundaries

Security testing without authorization is illegal under laws including:

| Jurisdiction | Law |
|---|---|
| 🇺🇸 United States | Computer Fraud and Abuse Act (CFAA) |
| 🇪🇺 European Union | Directive on Attacks Against Information Systems (2013/40/EU) |
| 🇬🇧 United Kingdom | Computer Misuse Act 1990 |
| 🌍 International | Budapest Convention on Cybercrime |

**Ethical principles followed in this project:**

- ✅ **Lawfulness** — Only tested systems with legal authorization
- ✅ **Confidentiality** — No real user data was accessed or exfiltrated
- ✅ **Non-maleficence** — No disruption to services or data destruction
- ✅ **Data minimization** — Did not store unnecessary sensitive data
- ✅ **Transparency** — All findings are documented honestly and accurately

---

### 3. Responsible Vulnerability Disclosure

In a real-world scenario, discovered vulnerabilities would be reported following the **ISO/IEC 29147** standard for vulnerability disclosure:

**Responsible Disclosure Process:**

1. **Document** the vulnerability with full reproduction steps and proof-of-concept.
2. **Identify** the appropriate security contact (security@company.com, HackerOne, Bugcrowd).
3. **Report privately** — never publicly disclose before the vendor has had time to remediate.
4. **Agree on a disclosure timeline** — typically 90 days (following Google Project Zero guidelines).
5. **Coordinate public disclosure** once a patch is available.
6. **Avoid** sharing exploit code publicly before a fix is in place.

For the OWASP Juice Shop, all vulnerabilities are **intentionally included** and publicly known — no disclosure was required. The Juice Shop project itself maintains a [public list of all challenges](https://github.com/juice-shop/juice-shop#challenges-covered-in-the-book-owasp-juice-shop---pwning-owasp-juice-shop).

---

### 4. Professional Conduct

As a Security Consultant / Penetration Tester, the following professional standards were maintained:

- **Objectivity** — Vulnerabilities are reported as found, without exaggeration or minimization.
- **Accuracy** — All exploitation steps are reproducible and verified.
- **Professionalism** — Findings are communicated clearly for both technical and non-technical audiences.
- **Continuous Learning** — Techniques and methodologies are kept current with evolving threat landscapes.
- **Community Contribution** — Knowledge is shared responsibly to improve the security community.

---

## Automated Scanning with OWASP ZAP

> This section addresses the **Bonus objective** — automated vulnerability scanning.

### Setup

```bash
# Pull and run OWASP ZAP
docker pull ghcr.io/zaproxy/zaproxy:stable

# Run automated baseline scan against Juice Shop
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
    -t http://host.docker.internal:3000 \
    -r zap_report.html
```

### Key Findings from ZAP Automated Scan

| Alert | Risk | CWE | Description |
|-------|------|-----|-------------|
| X-Content-Type-Options Missing | Low | CWE-693 | Browser MIME sniffing not disabled |
| X-Frame-Options Missing | Medium | CWE-1021 | Clickjacking protection absent |
| Content-Security-Policy Missing | Medium | CWE-693 | No CSP header to prevent XSS |
| Strict-Transport-Security Missing | Low | CWE-311 | HSTS not enforced |
| Cookie Without SameSite Attribute | Low | CWE-352 | CSRF risk on session cookies |
| SQL Injection | High | CWE-89 | Confirmed on login endpoint |
| XSS (Reflected) | High | CWE-79 | Confirmed on search parameter |
| Directory Browsing | Medium | CWE-548 | `/ftp/` listing enabled |

### ZAP Active Scan Commands

```bash
# Full active scan (aggressive — only run on authorized targets)
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py \
    -t http://host.docker.internal:3000 \
    -r zap_full_report.html \
    -J zap_full_report.json
```

> ⚠️ Active scanning sends attack payloads to the target. **Only run active scans on systems you are explicitly authorized to test.**

---

## Resources

| Resource | Link |
|----------|------|
| OWASP Juice Shop GitHub | https://github.com/juice-shop/juice-shop |
| OWASP Top 10 (2021) | https://owasp.org/www-project-top-ten/ |
| OWASP ZAP | https://owasp.org/www-project-zap/ |
| OWASP Testing Guide v4 | https://owasp.org/www-project-web-security-testing-guide/ |
| Juice Shop Docker Image | https://hub.docker.com/r/bkimminich/juice-shop |
| Hacksplaining OWASP Top 10 | https://www.hacksplaining.com/owasp |
| PortSwigger Web Security Academy | https://portswigger.net/web-security |
| Burp Suite Community Edition | https://portswigger.net/burp/communitydownload |
| jwt_tool | https://github.com/ticarpi/jwt_tool |
| Gobuster | https://github.com/OJ/gobuster |

---

<div align="center">

Made with ❤️ for ethical security research.  
**Never hack what you don't own or have permission to test.**

</div>
