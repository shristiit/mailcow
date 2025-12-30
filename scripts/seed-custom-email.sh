#!/bin/bash
set -euo pipefail

CONTAINER_NAME="mailcowdockerized-dovecot-mailcow-1"
DEFAULT_FROM_EMAIL="noreply@shristitech.com"
DEFAULT_FROM_NAME="Jira Bot"
FIXED_RECIPIENT="raghu.bezawada@shristitech.com"
TOUCH_TS_FROM_EPOCH() {
  local epoch_value=$1
  python3 - "$epoch_value" <<'PY'
import sys
from datetime import datetime, timezone

ts = int(sys.argv[1])
print(datetime.fromtimestamp(ts, timezone.utc).strftime("%Y%m%d%H%M.%S"))
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

epoch_to_rfc2822() {
  local epoch_value=$1
  python3 - "$epoch_value" <<'PY'
import sys
from datetime import datetime, timezone

ts = int(sys.argv[1])
print(datetime.fromtimestamp(ts, timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000"))
PY
}

TICKET_DATA=$(cat <<'EOF'
ticket_key|project_name|issue_type|status|priority|summary|description|assignee_name|assignee_email|created_by|created_by_email|created_on
PRAY-100|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of February for Sai Kiran and Riyaben Patel|Prepare and raise the February invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-02-17T00:00:00Z
PRAY-101|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of March for Sai Kiran and Riyaben Patel|Prepare and raise the March invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-03-21T23:00:00Z
PRAY-102|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of April for Sai Kiran and Riyaben Patel|Prepare and raise the April invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-04-08T23:00:00Z
PRAY-103|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of May for Sai Kiran and Riyaben Patel|Prepare and raise the May invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-05-15T23:00:00Z
PRAY-104|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of June for Sai Kiran and Riyaben Patel|Prepare and raise the June invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-06-16T23:00:00Z
PRAY-105|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of July for Sai Kiran and Riyaben Patel|Prepare and raise the July invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-07-18T23:00:00Z
PRAY-106|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of August for Sai Kiran and Riyaben Patel|Prepare and raise the August invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-08-20T23:00:00Z
PRAY-107|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of September for Sai Kiran and Riyaben Patel|Prepare and raise the September invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-09-22T23:00:00Z
PRAY-108|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of October for Sai Kiran and Riyaben Patel|Prepare and raise the October invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-10-10T00:00:00Z
PRAY-109|Prayag Solutions|TASK|DONE|Medium|Raise invoice for month of November for Sai Kiran and Riyaben Patel|Prepare and raise the November invoice for Sai Kiran and Riyaben Patel under Prayag Solutions.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-11-07T00:00:00Z
PARA-101|Paramount Consulting|TASK|DONE|Medium|Raise invoice for month of November for Arushi|Prepare and raise the November invoice for Arushi under Paramount Consulting.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-11-20T00:00:00Z
PARA-102|Paramount Consulting|TASK|DONE|Medium|Raise invoice for month of December for Arushi|Prepare and raise the December invoice for Arushi under Paramount Consulting.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-19T00:00:00Z
PARA-103|Paramount Consulting|TASK|DONE|Medium|Raise invoice for month of October for Arushi|Prepare and raise the October invoice for Arushi under Paramount Consulting.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-10-16T00:00:00Z
PARA-104|Paramount Consulting|TASK|DONE|Medium|Raise invoice for month of September for Arushi|Prepare and raise the September invoice for Arushi under Paramount Consulting.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-09-12T23:00:00Z
ACCO-100|Accolite Labs|TASK|DONE|Medium|Raise invoice for month of from November 24 to February 25 for Sireesh|Raise a consolidated invoice for Sireesh from Nov 2024 to Feb 2025 under Accolite Labs.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-02-07T00:00:00Z
ACCO-101|Accolite Labs|TASK|DONE|Medium|Raise invoice for month of March for Sireesh|Prepare and raise the March invoice for Sireesh under Accolite Labs.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-03-14T23:00:00Z
ACCO-102|Accolite Labs|TASK|DONE|Medium|Raise invoice for month of April for Sireesh|Prepare and raise the April invoice for Sireesh under Accolite Labs.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-04-18T23:00:00Z
INSTA-100|Insta CRM|TASK|DONE|Medium|Raise invoice for InstaCRM from Aug to Oct 2025|Raise the InstaCRM invoice covering August 2025 through October 2025.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-10-21T00:00:00Z
INSTA-101|Insta CRM|TASK|TODO|Medium|Raise invoice for InstaCRM from Nov 25 to Jan 26|Prepare the InstaCRM invoice for November 2025 through January 2026.|Raghu Bezawada|raghu.bezawada@shristitech.com|Raghu Bezawada|raghu.bezawada@shristitech.com|2025-12-23T00:00:00Z

EOF
)


while IFS='|' read -r ticket_key project_name issue_type status priority summary description assignee_name assignee_email created_by created_by_email created_on; do
  if [[ "$ticket_key" == "ticket_key" || -z "$project_name" ]]; then
    continue
  fi

  recipients=("$FIXED_RECIPIENT")

  if [[ ${#recipients[@]} -eq 0 ]]; then
    echo "Skipping \"$summary\" because no recipient emails were provided."
    continue
  fi

  FROM_NAME=$DEFAULT_FROM_NAME
  FROM_EMAIL=$DEFAULT_FROM_EMAIL
  SUBJECT="[$project_name][$ticket_key] $summary"

  if ! EPOCH_CREATED=$(iso_to_epoch "$created_on"); then
    EPOCH_CREATED=$(date +%s)
  fi
  DATE_HEADER=$(epoch_to_rfc2822 "$EPOCH_CREATED")

  for MAILBOX in "${recipients[@]}"; do
    if ! docker exec "$CONTAINER_NAME" doveadm user "$MAILBOX" >/dev/null 2>&1; then
      echo "Skipping $MAILBOX — mailbox not found."
      continue
    fi

    EMAIL_FILE=$(mktemp /tmp/custom-email.XXXXXX)
    ASSIGNEE_LINE="$assignee_name${assignee_email:+ <$assignee_email>}"
    CREATOR_LINE="${created_by:-Unknown}${created_by_email:+ <$created_by_email>}"
    BODY_DESCRIPTION=${description:-"(no description supplied)"}

    cat <<EOF > "$EMAIL_FILE"
From: $FROM_NAME <$FROM_EMAIL>
To: $MAILBOX
Subject: $SUBJECT
Date: $DATE_HEADER
MIME-Version: 1.0
Content-Type: text/plain; charset="UTF-8"

Project: $project_name
Ticket: $ticket_key
Issue Type: $issue_type
Status: $status
Priority: $priority
Summary: $summary

Description:
$BODY_DESCRIPTION

Assignee: $ASSIGNEE_LINE
Created By: $CREATOR_LINE


EOF

    # Build a one-off Maildir so the internal delivery time matches created_on.
    MAILDIR_HOST=$(mktemp -d /tmp/seed-maildir.XXXXXX)
    mkdir -p "$MAILDIR_HOST"/{cur,new,tmp}
    MAILFILE="${MAILDIR_HOST}/new/${EPOCH_CREATED}.M$$.$RANDOM.mailcowseed"
    mv "$EMAIL_FILE" "$MAILFILE"
    TOUCH_TIMESTAMP=$(TOUCH_TS_FROM_EPOCH "$EPOCH_CREATED")
    touch -t "$TOUCH_TIMESTAMP" "$MAILFILE"

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
    # Some setups create INBOX/INBOX; move everything into the primary INBOX to keep visibility consistent.
    docker exec "$CONTAINER_NAME" doveadm move -u "$MAILBOX" INBOX mailbox INBOX/INBOX all >/dev/null 2>&1 || true
    docker exec "$CONTAINER_NAME" rm -rf "$CONTAINER_MD"
    rm -rf "$MAILDIR_HOST"
  done
done <<< "$TICKET_DATA"

echo "✔ Completed seeding emails for assignees and creators."
