# Look System Application: System Architecture & Dataflow

## 1. Executive Overview

**Look System Application** is an enterprise-grade, transparent, and privacy-preserving system activity monitoring platform. It is engineered to provide organizations with productivity insights while guaranteeing employee privacy, adherence to workplace compliance regulations, and defense against covert surveillance practices.

---

## 2. Core Ethical Principles

* **Zero Covert Operation**: The desktop agent always displays an active system tray indicator and clear in-app status badges.
* **No Content Snooping**: Raw keystrokes, passwords, authentication credentials, clipboard data, and private message contents are strictly excluded from telemetry collection.
* **Consent & Transparency First**: Telemetry ingestion is locked until explicit user consent is recorded and verified.
* **Self-Service Subject Access**: Employees can review what telemetry was captured, export their full data archive (JSON/CSV), or exercise the Right to be Forgotten.

---

## 3. Component Architecture

```
+-------------------------------------------------------------------------+
|                       Authorized Workstation Device                     |
|                                                                         |
|  +---------------------------+       +-------------------------------+  |
|  | Look Desktop UI & Tray    | <---> | Look Monitor Service          |  |
|  | - Status Badge (🟢/🟡/⚪) |       | - Foreground Window Poller    |  |
|  | - Quick Pause Controls    |       | - OS Idle State Detector      |  |
|  | - Privacy Notice & Policy |       | - Window Title Sanitizer      |  |
|  +---------------------------+       +---------------+---------------+  |
|                                                      |                  |
|                                      +---------------v---------------+  |
|                                      | Encrypted Local Offline Buffer|  |
|                                      +---------------+---------------+  |
+------------------------------------------------------|------------------+
                                                       | (HTTPS Batch Ingestion)
                                                       v
+-------------------------------------------------------------------------+
|                        Look System Backend API                          |
|                                                                         |
|  +-------------------------+  +-------------------+  +----------------+ |
|  | Rate Limiter & Helmet   |  | Auth & RBAC Guard |  | Ingestion Hub  | |
|  +-------------------------+  +-------------------+  +----------------+ |
|                                                                         |
|  +-------------------------+  +-------------------+  +----------------+ |
|  | Audit Logging Service   |  | Retention Purge   |  | Analytics API  | |
|  +-------------------------+  +-------------------+  +----------------+ |
+-------------------------------------------------------------------------+
                                       |
                                       v
+-------------------------------------------------------------------------+
|               Encrypted PostgreSQL / SQLite Storage Layer               |
|                                                                         |
|  [organizations] [users] [devices] [activity_logs] [sessions]           |
|  [retention_policies] [audit_logs] [consent_records]                   |
+-------------------------------------------------------------------------+
```

---

## 4. Telemetry Pipeline & Sanitization

1. **Window Focus Event**: The desktop poller detects foreground application change.
2. **Idle Classification**: The OS input idle timer measures elapsed user inactivity without capturing keystroke contents.
3. **Data Sanitization**: `LookWindowSanitizer` cleans the window title:
   - Strips URL query parameters and bearer tokens.
   - Redacts email addresses (`[Redacted Email]`).
   - Redacts hexadecimal/base64 authentication keys (`[Redacted Token]`).
4. **Local Buffering**: Encrypted offline batching ensures minimal network load.
5. **Ingestion & Categorization**: The backend validates device authorization, verifies user consent, classifies the application into productivity categories, and stores the record with Row-Level Security (RLS).
