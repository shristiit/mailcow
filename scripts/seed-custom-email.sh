#!/bin/bash
set -euo pipefail

CONTAINER_NAME="mailcowdockerized-dovecot-mailcow-1"
DEFAULT_FROM_EMAIL="notifications@shristitech.com"
DEFAULT_FROM_NAME="Jira Bot"

iso_to_rfc2822() {
  local iso_value=$1
  python3 - "$iso_value" <<'PY'
import sys
from datetime import datetime, timezone

iso_raw = sys.argv[1]
try:
    dt = datetime.fromisoformat(iso_raw.replace("Z", "+00:00"))
except Exception:
    sys.exit(1)

print(dt.astimezone(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000"))
PY
}

iso_to_epoch() {
  local iso_value=$1
  python3 - "$iso_value" <<'PY'
import sys
from datetime import datetime, timezone

iso_raw = sys.argv[1]
try:
    dt = datetime.fromisoformat(iso_raw.replace("Z", "+00:00"))
except Exception:
    sys.exit(1)

print(int(dt.replace(tzinfo=timezone.utc).timestamp()))
PY
}

TICKET_DATA=$(cat <<'EOF'
project_name|issue_type|status|priority|summary|description|assignee_name|assignee_email|created_by|created_by_email|created_on
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of February for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:08:02.709Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of March for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:08:35.427Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of April for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:09:04.677Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of May for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:09:37.232Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of June for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:10:05.992Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of July for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:10:49.455Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of August for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:11:17.998Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of September for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:15:09.444Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of October for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:15:36.684Z
Prayag Solutions|TASK|TODO|Medium|Raise invoice for month of November for Sai Kiran and Riyaben Patel||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:16:09.361Z
Paramount Consulting|TASK|TODO|Medium|Raise invoice for month of November for Arushi||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:17:24.365Z
Paramount Consulting|TASK|TODO|Medium|Raise invoice for month of December for Arushi||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:18:05.099Z
Paramount Consulting|TASK|TODO|Medium|Raise invoice for month of October for Arushi||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:19:29.727Z
Paramount Consulting|TASK|TODO|Medium|Raise invoice for month of September for Arushi||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:20:18.001Z
Accolite Labs|TASK|TODO|Medium|Raise invoice for month of from November 24 to February 25 for Sireesh||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:27:33.600Z
Accolite Labs|TASK|TODO|Medium|Raise invoice for month of March for Sireesh||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:28:21.509Z
Accolite Labs|TASK|TODO|Medium|Raise invoice for month of April for Sireesh||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:29:08.593Z
Insta CRM|TASK|TODO|Medium|Raise invoice for InstaCRM from Aug to Oct 2025||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:31:28.233Z
Insta CRM|TASK|TODO|Medium|Raise invoice for InstaCRM from Nov 25 to Jan 26||Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-26T00:32:11.572Z
EOF
)

while IFS='|' read -r project_name issue_type status priority summary description assignee_name assignee_email created_by created_by_email created_on; do
  if [[ "$project_name" == "project_name" || -z "$project_name" ]]; then
    continue
  fi

  recipients=()
  [[ -n "$assignee_email" ]] && recipients+=("$assignee_email")
  if [[ -n "$created_by_email" && "$created_by_email" != "$assignee_email" ]]; then
    recipients+=("$created_by_email")
  fi

  if [[ ${#recipients[@]} -eq 0 ]]; then
    echo "Skipping \"$summary\" because no recipient emails were provided."
    continue
  fi

  FROM_NAME=${created_by:-$DEFAULT_FROM_NAME}
  FROM_EMAIL=${created_by_email:-$DEFAULT_FROM_EMAIL}
  SUBJECT="[$project_name] $summary"

  if ! DATE_HEADER=$(iso_to_rfc2822 "$created_on"); then
    DATE_HEADER=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
  fi

  for MAILBOX in "${recipients[@]}"; do
    if ! docker exec "$CONTAINER_NAME" doveadm user "$MAILBOX" >/dev/null 2>&1; then
      echo "Skipping $MAILBOX — mailbox not found."
      continue
    fi

    EMAIL_FILE=$(mktemp /tmp/custom-email.XXXXXX)
    ASSIGNEE_LINE="$assignee_name${assignee_email:+ <$assignee_email>}"
    CREATOR_LINE="${created_by:-Unknown}${created_by_email:+ <$created_by_email>}"
    BODY_DESCRIPTION=${description:-"(no description supplied)"}
    EPOCH_CREATED=$(iso_to_epoch "$created_on" || date +%s)

    cat <<EOF > "$EMAIL_FILE"
From: $FROM_NAME <$FROM_EMAIL>
To: $MAILBOX
Subject: $SUBJECT
Date: $DATE_HEADER
MIME-Version: 1.0
Content-Type: text/plain; charset="UTF-8"

Project: $project_name
Issue Type: $issue_type
Status: $status
Priority: $priority
Summary: $summary

Description:
$BODY_DESCRIPTION

Assignee: $ASSIGNEE_LINE
Created By: $CREATOR_LINE
Created On: $created_on

This message was seeded for mailbox testing.
EOF

    # Build a one-off Maildir so the internal delivery time matches created_on.
    MAILDIR_HOST=$(mktemp -d /tmp/seed-maildir.XXXXXX)
    mkdir -p "$MAILDIR_HOST"/{cur,new,tmp}
    MAILFILE="${MAILDIR_HOST}/new/${EPOCH_CREATED}.M$$.$RANDOM.mailcowseed"
    mv "$EMAIL_FILE" "$MAILFILE"

    echo "Seeding [$project_name] \"$summary\" into $MAILBOX..."
    CONTAINER_MD="/tmp/seed-maildir.$$"
    docker cp "$MAILDIR_HOST" "$CONTAINER_NAME":"$CONTAINER_MD"
    docker exec "$CONTAINER_NAME" sh -c "chown -R vmail:vmail '$CONTAINER_MD' && chmod -R 755 '$CONTAINER_MD'"
    if ! docker exec "$CONTAINER_NAME" doveadm import -u "$MAILBOX" "maildir:${CONTAINER_MD}" INBOX ALL; then
      echo "Failed to import into $MAILBOX; continuing to next item."
      docker exec "$CONTAINER_NAME" rm -rf "$CONTAINER_MD" || true
      rm -rf "$MAILDIR_HOST"
      continue
    fi
    docker exec "$CONTAINER_NAME" rm -rf "$CONTAINER_MD"
    rm -rf "$MAILDIR_HOST"
  done
done <<< "$TICKET_DATA"

echo "✔ Completed seeding emails for assignees and creators."
