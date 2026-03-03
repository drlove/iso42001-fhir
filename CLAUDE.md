# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository provides a bootstrap script (`bootstrap-claude.sh`) that initializes an ISO/IEC 42001-compliant AI Management System (AIMS) audit structure in any project directory. It is licensed under GPL-3.0.

## Running the bootstrap

```bash
# Run from within the target project directory (NOT this repo itself)
bash /path/to/bootstrap-claude.sh
```

The script is interactive and requires `uuidgen` to be available (standard on macOS; install `uuid-runtime` on Debian/Ubuntu).

## What the script creates

When executed in a target directory, it scaffolds:

- `governance/{policies,risk-register,model-cards}/` — AIMS policy documents
- `evidence/{prompts,outputs,decisions,logs}/` — AI interaction logs
- `provenance/fhir/` — HL7 FHIR Provenance JSON resources
- `audit/` — Audit helpers and commit timestamps
- `.git-hooks/pre-commit` — Auto-records commit timestamps to `audit/last_commit.yml`

### Key generated scripts

- **`audit/log_action.sh`** — Appends timestamped entries to `evidence/logs/claude-actions.log`. Run as: `./audit/log_action.sh <description>`
- **`provenance/create_provenance.sh`** — Generates a FHIR `Provenance` JSON resource linking the current Git commit hash to an AI activity record. Each run creates a new `provenance/fhir/provenance-<uuid>.json`.

## Architecture

The audit mechanism chains three layers:

1. **Git** as the immutable source of truth (the pre-commit hook writes `audit/last_commit.yml` on every commit)
2. **Manual activity log** (`audit/log_action.sh`) for human-readable AI interaction records
3. **FHIR Provenance resources** (`provenance/create_provenance.sh`) for machine-readable, interoperable audit trails linked to specific Git commits

The FHIR resources use `http://terminology.hl7.org/CodeSystem/provenance-activity-type` with code `AIASSIST` to classify Claude-assisted activities.
