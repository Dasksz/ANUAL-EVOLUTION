## 2026-04-16 - n8n Credential Redaction

**Vulnerability:** Third-party API credentials (like Chatwoot `api_access_token`) were exposed in exported n8n workflow JSON files, risking unauthorized access if the repository is public or compromised.
**Learning:** Hardcoded secrets in static declarative files (like n8n JSONs or Postman collections) are easily overlooked because they often sit deep inside node parameter definitions.
**Prevention:** Always implement automated or manual sanitization steps to replace API keys, tokens, and sensitive URLs with `REDACTED` or placeholders before committing workflow exports.
