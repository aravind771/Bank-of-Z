# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Application Platform
**Type:** IBM Z  
**Languages:** IBM Enterprise COBOL for z/OS, PL/I, JCL, HLASM (Assembler), Java (IMS bridge), JavaScript (frontend)

## CRITICAL: Git Commit Sign-off (DCO)
**ALL commits MUST use `-s` flag** — DCO checks are enforced and PRs with unsigned commits are rejected:
```bash
git commit -s -m "message"   # MANDATORY — never omit -s
```
To fix forgotten sign-offs: `git commit --amend -s --no-edit`

## Repository Structure (Non-obvious)
- `src/base/cics/cobol/` — CICS COBOL programs (main transaction path)
- `src/base/cics/copy/` — Shared COBOL copybooks for all CICS programs
- `src/base/batch/pli/` — Batch PL/I programs (currently only `BNKSTMT.pli`)
- `src/base/batch/jcl/` — Batch JCL (DSN RUN-based — DB2 connection via JCL, not explicit CONNECT)
- `src/base/ims/` — IMS COBOL programs (separate processing path from CICS)
- `src/*-ims-disabled/` — IMS Assembler DBD/PSB sources kept disabled; do not edit unless enabling IMS
- `src/api/` — z/OS Connect APIs (Gradle build, not compiled by DBB)
- `.setup/` — All z/OS automation: build (DBB), deploy (Wazi Deploy), provisioning (zconfig)
- `dbb-app.yaml` — DBB application descriptor: source patterns, compile options, deploy types
- `.setup/build/languages/PLI.yaml` — PL/I language task: `PP(SQL)` only added when `IS_SQL=true`
- `.setup/deploy/db2_bind_package.jcl.j2` — Bind template: LIBRARY resolves to `{{hlq}}.DBRM` (permanent), not `TMP.DBRM`
- `.setup/deploy/types_pattern_mapping.yml` — Deploy copies DBRM to `TMP.DBRM` first, then binds from `DBRM`, then copies to `DBRM` — bind happens before permanent copy

## Build and Deploy Pipeline
- **Full build:** `bash .setup/setup-remote.sh` (initial setup only)
- **Incremental pipeline:** `bash .setup/pipeline-remote.sh` (compile → bind → deploy changed files only)
- DBB impact build detects changes via file metadata store at `${SANDBOX_DIR}` — if change detection fails, force full rebuild
- Deploy sequence for SQL programs: `MEMBER_COPY → TMP.DBRM` → `BIND_PACKAGE (from DBRM)` → `MEMBER_COPY → DBRM` — the bind uses the *previous* DBRM unless `TMP.DBRM` path is used explicitly
- `BIND_PLAN` step is tagged as skipped in the current deploy configuration

## PL/I + DB2 Critical Gotchas
- `IS_SQL` is set by DBB scanner detecting `EXEC SQL` in source — `ScannerInit` in `dbb-app.yaml` currently only registers a Dummy scanner for `.yaml`; PL/I files rely on DBB's built-in SQL detection
- **Level-5 structure members as DB2 host variables** in PL/I cursor declarations are resolved by the precompiler but runtime behaviour depends on structure alignment — use standalone `DCL` variables for cursor WHERE clause parameters
- PL/I source margin is `MARGINS(2,72,1)` by default — code must not exceed column 72 or it is silently truncated
- `PP(SQL)` preprocessor treats `SQLCODE=` as a keyword even inside string literals — avoid `SQLCODE=nnn` in `PUT SKIP LIST` strings
- DB2 connection for batch PL/I is established via `DSN RUN` in JCL — no `EXEC SQL CONNECT` needed
- `ACCOUNT_SORTCODE` DB2 column is `CHAR(6)` — sort code `987654` is the canonical value (from `src/base/cics/copy/SORTCODE.cpy`)

## DB2 / Data Layout
- Plan: `BANKZPLN`, Package collection: `BANKZPACK` — batch PL/I bind collection differs from CICS programs
- DB2 subsystem: `DBDG`, bind qualifier: `BANKZ` (unqualified table names resolve to `BANKZ.*`)
- `ACCOUNT_OPENED`, `ACCOUNT_LAST_STATEMENT`, `ACCOUNT_NEXT_STATEMENT` are DB2 `DATE` columns — host variables mapped as `CHAR(10)` in PL/I
- `ACCOUNT_OVERDRAFT_LIMIT` is `INTEGER` — host variable must be `FIXED BIN(31)`

## Request Routing (Non-obvious)
- Customer ID prefix determines processing path: `Cnnnn` → CICS, `Innn` → IMS TM
- z/OS Connect routes to CICS or IMS based on this prefix — changing customer ID format breaks routing

## Technical Documentation
| Component | Documentation |
|---|---|
| Architecture overview | `docs/docs/architecture/` |
| Application flow & routing | `docs/docs/architecture/application-flow.md` |
| Build & deployment | `docs/docs/architecture/build-and-deployment.md` |
| Repository structure | `docs/docs/reference/repository-structure.md` |
| `BNKSTMT.pli` (batch statement) | `src/base/batch/pli/BNKSTMT.pli`, `src/base/batch/jcl/BNKSTMT.jcl` |
| CICS COBOL programs | `src/base/cics/cobol/`, copybooks in `src/base/cics/copy/` |

## Auto-Update Rules
1. When modifying a COBOL or PL/I program, check if related documentation exists in the table above
2. When modifying `dbb-app.yaml` or `.setup/build/languages/*.yaml`, verify `IS_SQL`/`IS_CICS` conditions are correct for the changed program
3. When adding a new PL/I program with embedded SQL, ensure `EXEC SQL` is present so DBB scanner sets `IS_SQL=true`
4. When modifying DB2 SQL in any program, verify the bind picks up the new DBRM — check `SYSIBM.SYSPACKAGE.BINDTIME` after deploy
