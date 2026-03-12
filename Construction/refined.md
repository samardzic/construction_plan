# Fireshield v1 — Backend QA Test Plan

---

## 1. Scope

This test plan covers **backend-side** components of the Fireshield traffic filtering system. Client-side SDK internals, Hydra Core policy enforcement, and frontend portal UI are out of scope unless they directly interact with a backend API under test.

**In Scope:**

- **catproxy** — Credential injection and request forwarding layer
- **Cat API BE** — Core categorization engine (credential validation, caching, provider integration, category mapping, rate limiting)
- **External Provider Integration** — Bit, Alphamountain, Bet, RPZ (via mocks in QA environments)
- **Remote Config API** — Configuration delivery to VPN SDKs
- **Project Config Storage (SD Repository)** — Configuration persistence, versioning, integrity
- **Admin Portal API** — Project enablement, provider configuration (API layer only)
- **Partner Portal API** — Rule management, category-action assignment (API layer only)

**Out of Scope:**

- Hydra Core internal VPN tunnel logic
- Client App UI/UX
- Portal front-end rendering

---

## 2. Requirements

| ID | Requirement |
|----|-------------|
| REQ-01 | Cat API BE must validate credentials on every incoming request from catproxy |
| REQ-02 | Categorization requests must include exactly one provider; 0 or >1 providers must return an error category |
| REQ-03 | Cat API BE must check its internal cache before querying any external provider |
| REQ-04 | Cat API BE must apply TTL-based caching: top-domain domains = 86400s, regular domains = 3600s, error/unknown categories = 60s |
| REQ-05 | All provider categories must map to a canonical Fireshield category (Malware, Adult Content, Social Media, Gambling, News, Unknown, Error) |
| REQ-06 | Domains in the internal list (Pointwild / Pango) must bypass external provider queries entirely |
| REQ-07 | Per-device and per-project rate limits must be enforced; exceeded requests must be rejected with a structured error response |
| REQ-08 | Remote Config API must return full FS configuration only for FS-enabled projects; disabled projects must receive `enabled: false` or an omitted FS section |
| REQ-09 | Project configuration isolation must be enforced — no project may access another project's config or categorization data |
| REQ-10 | All backend components must handle provider timeout, HTTP 4xx/5xx, and malformed responses without crashing or hanging |
| REQ-11 | catproxy must inject valid credentials into every upstream request and must not expose credentials in logs or responses |
| REQ-12 | Backward compatibility must be maintained for legacy integrations (Telenor, BitDefender client formats) |
| REQ-13 | Configuration changes must propagate from storage to Remote Config API within 5 minutes |
| REQ-14 | System must support ≥ 1000 categorization requests/second with P95 latency < 1000ms |

---

## 3. Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-01 | All Cat API BE endpoints return correct HTTP status codes and structured JSON for every defined success and error path |
| AC-02 | Cache hit ratio ≥ 80% under normal load simulation |
| AC-03 | Category mapping achieves 100% coverage for all known provider categories across Bit, Alpha, Bet, and RPZ |
| AC-04 | Requests with invalid credentials receive HTTP 401/403 and are never forwarded to providers |
| AC-05 | Rate-limit headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`) are present on all Cat API BE responses |
| AC-06 | Internal domain queries return correct category without generating any external provider call (verifiable via mock call count) |
| AC-07 | Provider timeout or failure results in `error` category with 60s TTL — no indefinite hang or 5xx propagated to Hydra |
| AC-08 | Remote Config API response time < 200ms at P95 under expected load |
| AC-09 | Zero cross-project data leakage in any tested API call |
| AC-10 | Legacy API formats from Telenor and BitDefender clients parse and respond correctly without modification |
| AC-11 | All error events are logged with sufficient context (request ID, component, error code, timestamp) |
| AC-12 | CI/CD pipeline (all automated backend tests) completes in < 30 minutes |

---

## 4. Test Scenarios

### 4.1 Cat API BE — Categorization Endpoint

- **Happy path:** Send valid request with one provider → expect canonical category and TTL in response
- **Cache hit:** Request same domain twice within TTL window → expect second response served from cache, no provider call made
- **Cache miss:** Request domain with expired or absent cache entry → expect provider queried and result cached
- **TTL assignment:** Verify top-domain returns 86400s TTL, regular domain returns 3600s, error category returns 60s
- **Zero providers:** Send request with empty `services` array → expect error category returned
- **Multiple providers:** Send request with two providers → expect error category returned
- **Invalid credentials:** Send request with missing or malformed credentials → expect HTTP 401/403, no provider query
- **Unknown category:** Mock provider to return a category not in the mapping table → expect `unknown` category with short TTL
- **Provider timeout:** Simulate provider response delay exceeding configured timeout → expect `error` category, no indefinite block
- **Provider HTTP 500:** Mock provider returning 500 → expect `error` category, event logged
- **Malformed provider response:** Mock provider returning invalid JSON → expect `error` category, no crash
- **Rate limit — per device:** Exceed configured per-device quota → expect structured rate-limit error response and correct headers
- **Rate limit — per project:** Exhaust project-level quota across multiple simulated devices → expect all project devices throttled
- **Cached result bypasses rate limit:** Confirm cached hits do not decrement rate-limit counter
- **Internal domain bypass:** Query domain present in Pointwild/Pango list → expect no external provider call, category from internal list

### 4.2 Category Mapping

- **Full mapping coverage:** For each known provider (Bit, Alpha, Bet, RPZ), send every documented provider category → verify correct canonical category returned
- **Consistent cross-provider mapping:** Verify `malicious_sites` (Bit), `harmful_websites` (Alpha), and `threats` (Bet) all map to `Malware`
- **Unmapped category handling:** Mock provider returning an undocumented category string → expect `unknown` canonical category, event logged

### 4.3 Internal Domains List

- **Exact match:** Query `admin.pointwild.com` → served from internal list, no provider call
- **Wildcard match:** Query subdomain matching `*.pointwild.com` pattern → served from internal list
- **Nested subdomain:** Query `api.staging.pointwild.com` → correctly matched by wildcard
- **Case-insensitivity:** Query domain with mixed case → matched correctly
- **Non-internal domain:** Query external domain not in list → proceeds to cache/provider flow normally

### 4.4 catproxy

- **Credential injection:** Intercept forwarded request at Cat API BE → verify credentials header is present and valid
- **Credential not in response:** Confirm credentials are stripped from response returned toward Hydra
- **Credential not logged:** Review catproxy logs for absence of credential values
- **Request forwarding reliability:** Under sustained load, verify all requests reaching catproxy arrive at Cat API BE with no loss
- **catproxy restart recovery:** Restart catproxy mid-load → verify requests resume successfully after restart

### 4.5 Remote Config API

- **FS-enabled project:** Authenticated SDK request for enabled project → full FS config returned including categories, actions, provider list
- **FS-disabled project:** Authenticated SDK request for disabled project → `enabled: false` returned or FS section omitted
- **Unauthorized request:** Request with invalid SDK token → HTTP 401/403 returned
- **Cross-project access attempt:** SDK authenticated for Project A requests Project B config → HTTP 403 returned
- **Config propagation:** Update a rule via Admin/Partner API, wait ≤ 5 minutes, re-fetch config → updated rule reflected
- **Response time:** Remote Config API P95 response ≤ 200ms under concurrent load

### 4.6 Project Configuration Storage

- **Persistence:** Save project config change, restart storage service, verify config retained
- **Concurrent writes:** Simulate concurrent configuration updates from Admin and Partner → no corruption, last-write-wins or conflict properly handled
- **Config versioning:** Confirm `rules_version` field increments on each rule update

### 4.7 Security & Isolation

- **Project data isolation:** SDK for Project A cannot retrieve categorization history or config of Project B
- **Admin-only endpoints:** Attempt Partner-level auth against Admin-only API → HTTP 403
- **SQL/JSON injection:** Send injection payloads in domain field → request rejected or sanitized, no internal error exposed
- **Misconfiguration detection:** Send categorization request for project with FS disabled → logged as misconfiguration, appropriate error returned

### 4.8 Backward Compatibility

- **Telenor legacy format:** Send request in legacy Telenor payload format → valid category response returned
- **BitDefender legacy format:** Send request in legacy BitDefender format → valid response, no schema errors
- **New canonical categories:** Confirm new category additions do not break legacy client response parsing (optional fields)

### 4.9 Error Handling & Resilience

- **Cat API BE crash/restart:** Kill and restart Cat API BE during load → verify service recovers, no data loss in config storage
- **Config storage unavailable:** Take down storage service → Remote Config API returns cached or last-known config, appropriate error logged
- **Network partition (catproxy → Cat API BE):** Simulate network drop → catproxy returns error to Hydra, logs event, does not hang
- **High load / spike:** Ramp requests to 1.5× target throughput → verify P99 latency stays within bounds, no OOM crash
- **Log completeness:** After any error scenario, confirm logs contain: request ID, component name, error code, and timestamp

---

## 5. Test Environment Prerequisites

### 5.1 Infrastructure

- All backend services deployed and reachable: `catproxy`, `Cat API BE`, `Remote Config API`, `Project Config Storage`
- Services isolated from production data and traffic
- Admin Portal and Partner Portal APIs accessible for configuration setup calls
- Network controls in place to allow traffic injection and blocking between components for resilience tests

### 5.2 Mock Provider Framework

A controllable mock must be deployed for each external provider (Bit, Alphamountain, Bet, RPZ) supporting:

- Configurable response payload per domain (category string, HTTP status code)
- Configurable artificial delay (to simulate timeouts)
- Error injection modes: HTTP 500, connection refused, malformed JSON body
- Request counter endpoint — queryable by test scripts to assert provider call counts

### 5.3 Test Data

- A set of domains pre-loaded for each provider category (malware, adult, gambling, social, news domains)
- At least one domain per provider mapped to a canonical category
- At least one domain intentionally absent from all provider mock mappings (for `unknown` category tests)
- Pointwild and Pango domain samples (exact and wildcard) pre-loaded in the internal domains list
- Project fixtures: one FS-enabled project with rules, one FS-disabled project, one legacy-format project (Telenor, BitDefender)

### 5.4 Tooling

- **API testing:** Python + `pytest` + `requests` or Postman / Newman collections wired into CI
- **Load testing:** Locust or k6 scripts targeting Cat API BE and Remote Config API
- **Log inspection:** Access to aggregated logs (ELK stack or equivalent) for error verification
- **CI/CD integration:** Jenkins pipeline executing smoke, regression, and integration test stages; full suite must complete in < 30 minutes

### 5.5 Access & Permissions

- QA credentials with Admin-level access to seed project configurations
- SDK-level tokens for at least two distinct test projects
- Read access to Cat API BE and catproxy application logs
- Access to provider mock control API to configure responses per test case

---

*Document version: 1.0 | Scope: Fireshield v1 Backend | Status: Draft*
