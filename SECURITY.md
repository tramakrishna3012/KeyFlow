# KeyFlow Security Model

## Overview

KeyFlow is designed as a **personal productivity application** with user consent and privacy as core principles. This document outlines the security architecture, threat model, and best practices.

## Security Architecture

### 1. Authentication & Authorization

**Authentication:**
- BCrypt password hashing with 12 salt rounds
- JWT tokens for session management (24-hour expiration)
- Account lockout after 5 failed login attempts (15-minute lockout)
- Minimum 12-character passwords with complexity requirements:
  - At least one uppercase letter
  - At least one lowercase letter
  - At least one number
  - At least one special character

**Authorization:**
- All API endpoints require valid JWT authentication
- User data strictly isolated by user_id
- No user can access another user's typing history or clipboard data
- Admin and manager roles for organization-level functions
- Audit logging for all sensitive operations

### 2. Data Encryption

**At Rest:**
- Typing history encrypted with AES-256-GCM
- Clipboard content encrypted with AES-256-GCM
- Unique 96-bit initialization vector (IV) per record
- Authentication tags verify data integrity

**In Transit:**
- All API communication over HTTPS required in production
- JWT tokens transmitted in Authorization header
- No sensitive data in URL parameters

### 3. Privacy Controls

**User Consent:**
- Explicit onboarding explaining data collection
- Consent tracking in database
- Right to be forgotten (GDPR/CCPA compliance)
- Data export capability

**Sensitive Data Filtering:**
- Password fields automatically excluded
- Pattern-based redaction for:
  - Credit card numbers (13-16 digits)
  - CVV codes
  - Bearer tokens
  - API keys
  - One-time passwords (6-8 digits)
- Configurable application exclusions (e.g., password managers, banking apps)

**Data Minimization:**
- 90-day default retention policy
- Automated purge jobs
- User-controlled deletion

### 4. Application Security

**Input Validation:**
- All inputs validated at API layer
- Parameterized SQL queries (no string concatenation)
- Content-length limits (5MB max)

**Rate Limiting:**
- 200 requests per minute per IP address
- Applied globally to all endpoints

**Error Handling:**
- Stack traces only exposed in development mode
- Generic error messages in production
- Structured logging for debugging

**CORS Configuration:**
- Configurable allowed origins
- Restrictive in production
- Development hosts allowed for local testing

## Threat Model

### In Scope
- Unauthorized access to user data (IDOR vulnerabilities)
- Credential theft and session hijacking
- SQL injection attacks
- Cross-site scripting (XSS)
- Privilege escalation
- Insecure direct object references

### Out of Scope
- Physical device compromise
- Malware on user's device
- Social engineering attacks
- Denial of service (DDoS)
- Side-channel attacks

## Security Best Practices

### For Administrators

1. **Never commit secrets to version control**
   - Use environment variables for all sensitive configuration
   - Set strong JWT_SECRET (minimum 32 characters random)
   - Rotate secrets regularly

2. **Secure deployment**
   - Always use HTTPS in production
   - Set NODE_ENV=production
   - Configure firewall rules
   - Enable database backups

3. **Monitoring**
   - Review audit logs regularly
   - Monitor failed login attempts
   - Track unusual API patterns
   - Set up alerts for security events

4. **Updates**
   - Keep dependencies updated
   - Apply security patches promptly
   - Review CVE reports

### For Developers

1. **Authentication**
   - Never bypass authentication middleware
   - Always validate user_id in database queries
   - Check authorization before returning data

2. **Data Handling**
   - Encrypt sensitive data at rest
   - Never log passwords, tokens, or PII
   - Use parameterized queries exclusively
   - Validate all user inputs

3. **Code Review**
   - Security review for all authorization changes
   - Test with multiple user accounts
   - Verify IDOR protections
   - Check for information disclosure

## Reported Vulnerabilities & Fixes

### v1.0.1 Security Fixes (2024)

**CRITICAL:**
1. **IDOR in sessionRoutes.js** - Fixed: Added user_id validation to session retrieval
2. **IDOR in clipboardRoutes.js** - Fixed: Added user_id validation to clipboard retrieval
3. **Hardcoded JWT_SECRET** - Fixed: Removed from docker-compose.yml, now requires environment variable
4. **Direct Supabase access** - Fixed: Removed client-side database access, all data flows through authenticated API

**HIGH:**
5. **Unencrypted clipboard data** - Fixed: Added AES-256-GCM encryption to clipboard_entries
6. **Weak password policy** - Fixed: Increased minimum to 12 characters with complexity requirements
7. **Stack trace leakage** - Fixed: Stack traces only in development mode

## Security Contact

For security issues, please email: security@keyflow.example.com

**Do not file public issues for security vulnerabilities.**

## Compliance

- GDPR: Data export and deletion capabilities
- CCPA: Right to know and delete personal information
- SOC 2 Type II: Audit logging and access controls
- ISO 27001: Information security management

## Security Checklist for Production

- [ ] JWT_SECRET set to strong random value (32+ chars)
- [ ] NODE_ENV=production
- [ ] HTTPS configured and enforced
- [ ] Database backups enabled
- [ ] CORS configured for production domains only
- [ ] Error stack traces disabled
- [ ] Audit logging enabled
- [ ] Rate limiting configured
- [ ] Password policy enforced
- [ ] Encryption keys secured
- [ ] Direct database access disabled from clients
- [ ] .env file not committed to version control
- [ ] All dependencies updated
- [ ] Security headers configured (Helmet.js)

## License

This security model is part of the KeyFlow project and licensed under the MIT License.
