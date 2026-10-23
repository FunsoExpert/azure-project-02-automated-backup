# Security Notes: Automated Backup System

Project: Azure Automated Backup System (portfolio project 2)
Last updated: 17 Oct 2026

## 1. Security objectives

1. Business documents can't be lost to accidental overwrite, deletion, or loss of a region.
2. Access is identity-based, least-privilege, and auditable.
3. No secrets are stored in the workflow, repo, or storage accounts.
4. Backup health is verified daily, and silence is treated as a failure.

## 2. Controls implemented

| Control | Applied to | Why |
|---|---|---|
| Anonymous blob access disabled | Source, replica | Prevents data being exposed through a public container |
| HTTPS only, minimum TLS 1.2 | Source, replica | Encrypts data in transit and blocks legacy protocols |
| Shared key access disabled | Source, replica | Keys bypass RBAC and can't be tied to a person. Entra ID auth only |
| Managed identity for automation | Logic App `la-backup-healthcheck` | No keys, passwords, or connection strings in the workflow |
| Least-privilege roles | See section 3 | The automation can read settings and blobs. It can't write or delete |
| Blob versioning | Source, replica | Recovers from overwrites and deletions |
| Soft delete (7 days, blobs and containers) | Source, replica | Second layer for deleted versions and containers |
| Point-in-time restore (6 days) | Source | Recovers a container after bulk damage |
| Object replication (France Central to Sweden Central) | Source to replica | Protects against regional loss |
| Delete lock (`lock-no-delete`) | Source, replica | Blocks accidental deletion of the account |
| Lifecycle policy | Source | Tiers old versions to Cool after 30 days, deletes after 90, so version growth stays under control |
| Resource tags (`app`, `costcenter`, `env`) | All resources | Ownership and cost attribution |
| Daily health check with three outcomes | Logic App | Healthy, alert, or "check did not run" |

## 3. Role assignments (RBAC)

| Principal | Source account | Replica account |
|---|---|---|
| `la-backup-healthcheck` (system-assigned managed identity) | Reader, Storage Blob Data Reader | Reader, Storage Blob Data Reader |
| Project owner (user) | Storage Blob Data Contributor | Storage Blob Data Reader |

Notes:
- The managed identity can read account settings and list blobs. It has no write or delete permission.
- The project owner also holds Owner inherited from the subscription. This is acceptable for a lab. In production this would be time-limited through Privileged Identity Management.

## 4. Verification evidence

| Test | Result | Screenshot |
|---|---|---|
| Account deletion blocked by lock | Delete refused with a lock error | `phase4-delete-blocked.png` |
| Overwrite recovery | Previous version restored | `phase1-versions.png` |
| Replication | Blob appears in the replica, status Complete | `phase3-source-replication-status.png` |
| Health check, healthy path | Email with all checks True and counts matching | `phase5c-test1-healthy.png` |
| Health check, alert path | Email with replica count 0 | `phase5c-test2-alert.png` |
| Health check, check-did-not-run path | High-importance email when a step failed | `phase5c-test3-did-not-run.png` |
| Scheduled run, unattended | 07:00 healthy email, no manual trigger | `phase6-scheduled-run.png` |
| Replication after hardening | Counts 3 and 3 after a new blob | `phase6-post-hardening.png` |
| RBAC review | Role assignments match section 3 | `phase6-iam-source.png` |

## 5. Known limitations and trade-offs

1. **No storage firewall.** A Consumption Logic App calls out from a large shared pool of regional IP addresses, so an IP allow-list would be fragile and unreliable. Compensating controls: Entra-only authentication, no anonymous access, least-privilege RBAC. Future work: a private endpoint with a Logic App Standard plan and VNet integration.
2. **Delete lock protects against accidents, not privileged users.** Anyone with Owner can remove the lock. Future work: immutable (WORM) storage on the replica.
3. **Replication is asynchronous.** The RPO is minutes, not zero. A health check run during a replication delay could raise a false alert, because it compares blob counts.
4. **Replica deletion behaviour.** How deletions on the source propagate to the replica will be confirmed in the recovery drills.
5. **Email uses a personal Outlook.com connection.** It authenticates as a user, not a managed identity. Production alternative: an Azure Monitor action group.
6. **No alert if the Logic App itself stops running.** A missing-run alert is a stretch goal.
7. **Backup scope.** This covers blob data only. VMs and databases are out of scope (that's Azure Backup).

## 6. Future improvements

- Private endpoint and Logic App Standard with VNet integration
- Immutable storage on the replica
- Missing-run alert for the health check
- Capacity-growth alert to catch version bloat early
- Azure Policy (Audit) for shared key access and required tags