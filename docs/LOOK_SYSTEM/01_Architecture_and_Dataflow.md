# Look System Application: System Architecture & Dataflow

## 1. Executive Overview

**Look System Application** is an enterprise-grade, transparent, and privacy-preserving system activity monitoring platform. It is engineered to provide organizations with productivity insights while guaranteeing employee privacy, adherence to workplace compliance regulations, and defense against covert surveillance practices.

---

## 2. Core Ethical Principles

* **Zero Covert Operation**: The desktop agent always displays an active system tray indicator and clear in-app status badges.
* **No Content Snooping**: Passwords, OTPs, authentication credentials, credit/debit card numbers, banking credentials, and private clipboard secrets are strictly excluded from telemetry collection.
* **Consent & Transparency First**: Telemetry ingestion is locked until explicit user consent is recorded and verified.
* **Hierarchical Organization**: Monitored data is structured logically as `Session -> Applications -> Activity Events & Permitted Text Records`.
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
|  | - Session Controls        |       | - OS Idle State Detector      |  |
|  |   (Start/Pause/Resume)    |       | - Sensitive Pattern Sanitizer |  |
|  | - Privacy Exclusions      |       | - App Hierarchy Grouping      |  |
|  +---------------------------+       +---------------+---------------+  |
|                                                      |                  |
|                                      +---------------v---------------+  |
|                                      | Offline Encrypted Queue       |  |
|                                      | - Deduplication UUIDs         |  |
|                                      | - Exponential Backoff Sync    |  |
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
|  | Session Tree Engine     |  | Retention Purge   |  | Search Engine  | |
|  | - App Grouping Aggregator| | (Auto-cryptopurge)|  | - Multi-filter | |
|  +-------------------------+  +-------------------+  +----------------+ |
+-------------------------------------------------------------------------+
                                       |
                                       v
+-------------------------------------------------------------------------+
|               Encrypted PostgreSQL / SQLite Storage Layer               |
|                                                                         |
|  [organizations] [users] [devices] [sessions] [applications]            |
|  [activity_events] [text_records (AES-256-GCM)] [privacy_exclusions]   |
|  [retention_policies] [audit_logs] [consent_records]                   |
+-------------------------------------------------------------------------+
```

---

## 4. Telemetry Pipeline & Hierarchical Aggregation

1. **Explicit Session Initiation**: User signs in and explicitly triggers `Start Session` from the desktop client.
2. **Window Focus Event**: The desktop poller detects foreground application change with minimal CPU consumption (< 1% CPU utilization).
3. **Idle Classification**: The OS input idle timer measures elapsed user inactivity without capturing keystroke contents.
4. **Data Sanitization & Redaction**:
   - Strips URL query parameters and bearer tokens.
   - Redacts email addresses (`[Redacted Email]`).
   - Redacts payment cards (`[Redacted Card Number]`).
   - Redacts authentication secrets & OTPs (`[Redacted Secret]`, `[Redacted Token]`).
   - Bypasses custom user-configured privacy exclusion applications.
5. **Local Offline Buffering & Deduplication**: If network connectivity drops, telemetry is queued locally with client UUIDs. Upon reconnect, batches are synced with exponential backoff and deduplicated on the backend.
6. **Hierarchical Storage**:
   - `sessions` stores session duration and state.
   - `applications` tracks cumulative active duration per app in that session.
   - `activity_events` and `text_records` are linked with foreign keys and encrypted at rest with AES-256-GCM.
