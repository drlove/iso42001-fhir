#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
# This prevents the script from running partially if an error occurs.
set -e

# ---------------------------------------------------------
# 1. User Confirmation Gate
# ---------------------------------------------------------
# Prevents accidental execution in the wrong directory.
read -p "Initialize ISO 42001 audit structure in $PWD? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Bootstrap cancelled."
    exit 1
fi

# ---------------------------------------------------------
# 2. Dependency Check
# ---------------------------------------------------------
# Ensures 'uuidgen' is available for the FHIR provenance generator (Section 5).
command -v uuidgen >/dev/null 2>&1 || { 
    echo "Error: 'uuidgen' is not installed. Please install it to generate FHIR provenance IDs."
    exit 1 
}

# Define dynamic variables for project naming and documentation timestamps.
PROJECT_NAME=$(basename "$PWD")
DATE=$(date +"%Y-%m-%d")

echo "=== Secure Claude Cowork Bootstrap ==="
echo "Project: $PROJECT_NAME"

########################################
# 1. Initialize Git Audit Trail
########################################
# Sets up Git as the version control 'source of truth' for the audit trail.
if [ ! -d ".git" ]; then
  git init
  # Disabling GPG sign for compatibility; change to 'true' for higher security.
  git config commit.gpgsign false
  # Ensures consistent line endings across different operating systems.
  git config core.autocrlf input
  # Standardizes pull behavior to prevent merge-conflict mess in audit logs.
  git config pull.rebase false
fi

# Redirects Git hooks to a local folder so they can be version-controlled.
mkdir -p .git-hooks
git config core.hooksPath .git-hooks

########################################
# 2. ISO 42001 Evidence Structure
########################################
# Creates the standard directory hierarchy required for an AI Management System (AIMS).
# - governance: Policies and Risk Registers.
# - evidence: Logs of AI interactions (prompts/outputs).
# - provenance: Machine-readable history (FHIR).
mkdir -p governance/{policies,risk-register,model-cards}
mkdir -p evidence/{prompts,outputs,decisions,logs}
mkdir -p provenance/fhir
mkdir -p audit
mkdir -p ig  # Implementation Guide: FHIR IG artifacts and configuration

########################################
# 2a. .gitignore for ISO 42001 Folders
########################################
# Excludes sensitive AIMS folders from being synced to GitHub.
# These directories may contain private policies, AI interaction logs,
# audit records, and provenance data that should remain local.
cat > .gitignore <<'EOF'
# ISO/IEC 42001 AIMS — do not sync to GitHub
governance/
evidence/
provenance/
audit/
EOF

# Generates the initial AIMS documentation header.
cat > governance/README.md <<EOF
ISO/IEC 42001 AI Management System Evidence
Project: $PROJECT_NAME
Initialized: $DATE
EOF

########################################
# 3. Claude Activity Logger
########################################
# Creates a helper script to manually log specific AI actions or manual reviews.
cat > audit/log_action.sh <<'EOF'
#!/usr/bin/env bash
TS=$(date -Iseconds)  # ISO 8601 timestamp
USER=$(whoami)
MSG="$*"

# Appends the action to a persistent log file.
echo "$TS | $USER | $MSG" >> evidence/logs/claude-actions.log
EOF

# Makes the logger executable.
chmod +x audit/log_action.sh

########################################
# 4. Git Auto-Audit Hook (pre-commit)
########################################
# Automates the tracking of every commit by updating a timestamp file.
# This ensures every 'git commit' leaves a trace in the 'audit/' directory.
cat > .git-hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
TS=$(date -Iseconds)

echo "Recording AI audit trail..."

# Store the exact time of the commit for cross-referencing logs.
echo "commit_time: $TS" > audit/last_commit.yml
git add audit/last_commit.yml
EOF

chmod +x .git-hooks/pre-commit

########################################
# 5. FHIR Provenance Generator
########################################
# Creates a script that generates HL7 FHIR-compliant Provenance resources.
# This links specific AI activities to the current Git commit hash.
cat > provenance/create_provenance.sh <<'EOF'
#!/usr/bin/env bash

ID=$(uuidgen)
TS=$(date -Iseconds)
# Captures the current Git commit hash to link the code state to the AI action.
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "uncommitted")

# Generates a machine-readable JSON file for interoperable audit logs.
cat > provenance/fhir/provenance-$ID.json <<EOP
{
  "resourceType": "Provenance",
  "id": "$ID",
  "recorded": "$TS",
  "activity": {
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/provenance-activity-type",
      "code": "AIASSIST"
    }]
  },
  "agent": [{
    "type": { "text": "AI Assistant" },
    "who": { "display": "Claude Cowork" }
  }],
  "entity": [{
    "role": "source",
    "what": { "display": "Git commit $COMMIT" }
  }]
}
EOP

echo "FHIR Provenance created."
EOF

chmod +x provenance/create_provenance.sh

########################################
# 6. Initial Commit
########################################
# Stages all files and performs the first commit to lock in the initial environment.
git add .
git commit -m "Initialize secure cowork environment ($DATE)" || true

echo "=== Bootstrap Complete ==="
echo "Run: claude cowork"


