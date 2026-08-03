#!/bin/bash

set -Eeuo pipefail

source ../common.sh


header \
"Jenkins Job Creation" \
"This script creates Jenkins pipeline job from Git repository."

usage() {

    echo
    echo "Usage:"
    echo "$0 \\"
    echo "  -repo      -- repository  url \\"
    echo "  -branch    -- branch name \\"
    echo "  -job       -- job_name \\"
    echo "  -schedule  -- schedule (cron) \\"
    echo "  -jenkins   -- jenkins_url \\"
    echo "  -user      -- jenkins_user \\"
    echo "  -pass      -- jenkins_password"
    echo
    exit 1
}



step "Checking system"

info "Checking dependencies"

command -v curl >/dev/null || {
    error "curl is required"
    exit 1
}

command -v python3 >/dev/null || {
    error "python3 is required"
    exit 1
}

success


step "Reading configuration"

info "Parsing arguments"

GIT_REPOSITORY=""
BRANCH_NAME=""
JOB_NAME=""
POLL_SCHEDULE=""
JENKINS_URL=""
JENKINS_USER=""
JENKINS_PASS=""
JENKINSFILE_NAME="jenkinsfile"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -repo)
            GIT_REPOSITORY="$2"
            shift 2
            ;;
        -branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        -job)
            JOB_NAME="$2"
            shift 2
            ;;
        -schedule)
            POLL_SCHEDULE="$2"
            shift 2
            ;;
        -jenkins)
            JENKINS_URL="$2"
            shift 2
            ;;
        -user)
            JENKINS_USER="$2"
            shift 2
            ;;
        -pass)
            JENKINS_PASS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

info "Validating configuration"

if [[ -z "${GIT_REPOSITORY}" ||
      -z "${BRANCH_NAME}" ||
      -z "${JOB_NAME}" ||
      -z "${POLL_SCHEDULE}" ||
      -z "${JENKINS_URL}" ||
      -z "${JENKINS_USER}" ||
      -z "${JENKINS_PASS}" ]]; then

    error "Missing required parameters"
    usage
fi

echo
echo "Configuration Summary"
echo "---------------------"
echo "Jenkins URL : ${JENKINS_URL}"
echo "Repository  : ${GIT_REPOSITORY}"
echo "Branch      : ${BRANCH_NAME}"
echo "Job         : ${JOB_NAME}"
echo "Schedule    : ${POLL_SCHEDULE}"
echo

ask_yes_no "Create Jenkins job?" || exit 0

success


step "Creating Jenkins pipeline"

info "Create temp files"

TMP_XML=$(mktemp /tmp/jenkins-job-XXXXXX.xml)
COOKIE_JAR=$(mktemp /tmp/jenkins-cookie-XXXXXX.txt)
RESPONSE_FILE=$(mktemp /tmp/jenkins-response-XXXXXX.txt)

cleanup() {
  step "Removing temp files"
  rm -f "$TMP_XML" "$COOKIE_JAR" "$RESPONSE_FILE"
  success
}

trap cleanup EXIT

info "Requesting Jenkins crumb"

CRUMB_JSON=$(curl -fsS \
    -u "${JENKINS_USER}:${JENKINS_PASS}" \
    -c "${COOKIE_JAR}" \
    "${JENKINS_URL}/crumbIssuer/api/json"
)

CRUMB_FIELD=$(echo "${CRUMB_JSON}" |
    python3 -c \
    "import sys,json; print(json.load(sys.stdin)['crumbRequestField'])"
)

CRUMB_VALUE=$(echo "${CRUMB_JSON}" |
    python3 -c \
    "import sys,json; print(json.load(sys.stdin)['crumb'])"
)

info "Generating Jenkins job configuration"

cat > "$TMP_XML" <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>CI/CD Pipeline (Git polling)</description>
  <keepDependencies>false</keepDependencies>

  <triggers>
    <hudson.triggers.SCMTrigger>
      <spec>${POLL_SCHEDULE}</spec>
    </hudson.triggers.SCMTrigger>
  </triggers>

  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">

      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${GIT_REPOSITORY}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>

      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/${BRANCH_NAME}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>

    </scm>

    <scriptPath>${JENKINSFILE_NAME}</scriptPath>
    <lightweight>true</lightweight>
  </definition>
</flow-definition>
EOF

info "Creating Jenkins job: ${JOB_NAME}"

HTTP_CODE=$(curl -s \
    -o "${RESPONSE_FILE}" \
    -w "%{http_code}" \
    -X POST \
    -H "${CRUMB_FIELD}: ${CRUMB_VALUE}" \
    -H "Content-Type: application/xml" \
    -b "${COOKIE_JAR}" \
    --user "${JENKINS_USER}:${JENKINS_PASS}" \
    --data-binary @"${TMP_XML}" \
    "${JENKINS_URL}/createItem?name=${JOB_NAME}"
    )

if [[ "${HTTP_CODE}" != "200" ]]; then
    error "Failed to create Jenkins job"
    echo
    cat "${RESPONSE_FILE}"
    exit 1
fi

success


step "Jenkins job created"

info "Job name: ${JOB_NAME}"


footer