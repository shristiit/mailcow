#!/bin/bash
set -euo pipefail

# ---------------- CONFIG ----------------
CONTAINER_NAME="mailcowdockerized-dovecot-mailcow-1"
HR_MAILBOX="hr@shristitech.com"
MSG_DOMAIN="shristitech.com"
INSTA_EMAIL="rajesh@bangerfinlabs.com"
PRAYAG_EMAIL="info@prayagsolution.com"
# ----------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

epoch_to_rfc2822() {
  python3 - "$1" <<'PY'
from datetime import datetime, timezone
import sys
print(datetime.fromtimestamp(int(sys.argv[1]), timezone.utc)
      .strftime("%a, %d %b %Y %H:%M:%S +0000"))
PY
}

epoch_to_touch() {
  python3 - "$1" <<'PY'
from datetime import datetime, timezone
import sys
print(datetime.fromtimestamp(int(sys.argv[1]), timezone.utc)
      .strftime("%Y%m%d%H%M.%S"))
PY
}

randomize_epoch_workhours() {
  # Place a timestamp within working hours (08:00–18:59 UTC) on the same date.
  python3 - "$1" <<'PY'
import sys, random
from datetime import datetime, timezone

base = datetime.fromtimestamp(int(sys.argv[1]), timezone.utc)
hour = random.randint(8, 18)
minute = random.randint(0, 59)
second = random.randint(0, 59)
dt = base.replace(hour=hour, minute=minute, second=second)
print(int(dt.replace(tzinfo=timezone.utc).timestamp()))
PY
}

datetime_to_epoch() {
  python3 - "$1" <<'PY'
from datetime import datetime, timezone
import sys
dt = datetime.strptime(sys.argv[1], "%Y-%m-%d %H:%M")
print(int(dt.replace(tzinfo=timezone.utc).timestamp()))
PY
}

ensure_mailbox_exists() {
  if ! docker exec "$CONTAINER_NAME" doveadm user "$1" >/dev/null 2>&1; then
    echo "Mailbox $1 not found in $CONTAINER_NAME"
    exit 1
  fi
}

purge_existing_message() {
  local msg_id="$1"
  docker exec "$CONTAINER_NAME" doveadm expunge -u "$HR_MAILBOX" \
    mailbox '*' "header Message-ID $msg_id" >/dev/null 2>&1 || true
}

mime_type_for() {
  python3 - "$1" <<'PY'
import mimetypes
import sys

mime, _ = mimetypes.guess_type(sys.argv[1])
print(mime or "application/octet-stream")
PY
}

resolve_attachment_path() {
  local path="$1"
  if [[ -z "$path" ]]; then
    printf '%s' ""
    return
  fi
  if [[ "$path" = /* ]]; then
    printf '%s' "$path"
  else
    printf '%s' "$SCRIPT_DIR/$path"
  fi
}

write_message() {
  local file_path="$1"
  local from_header="$2"
  local to_header="$3"
  local subject="$4"
  local date_header="$5"
  local msg_id="$6"
  local body="$7"
  local attachment_path="${8:-}"

  if [[ -n "$attachment_path" ]]; then
    if [[ ! -f "$attachment_path" ]]; then
      echo "Attachment not found: $attachment_path" >&2
      exit 1
    fi

    local boundary filename mime_type
    boundary="====MAILCOW_BOUNDARY_${RANDOM}_$$===="
    filename=$(basename "$attachment_path")
    mime_type=$(mime_type_for "$attachment_path")

    {
      cat <<EOF
From: $from_header
To: $to_header
Subject: $subject
Date: $date_header
Message-ID: $msg_id
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="$boundary"

--$boundary
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: 8bit

$body

--$boundary
Content-Type: $mime_type; name="$filename"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$filename"

EOF
      base64 < "$attachment_path"
      printf '\n'
      cat <<EOF
--$boundary--
EOF
    } > "$file_path"
  else
    cat <<EOF > "$file_path"
From: $from_header
To: $to_header
Subject: $subject
Date: $date_header
Message-ID: $msg_id
MIME-Version: 1.0
Content-Type: text/plain; charset="UTF-8"

$body
EOF
  fi
}

EMAIL_ROWS=$(cat <<'EOF'
Sajan Ganeshmooprthy|sajan@shristitech.com|2025-10-05|2025-10-15|2025-12-10|Vacation Leave 
Mounika Challa|mounika@shristitech.com|2025-11-06|2025-11-17|2025-11-20|Vacation Leave  
Mahender Reddy|mahender.reddy@shristitech.com|2025-02-12|2025-02-17|2025-02-28|Vacation Leave  
Mahender Reddy|mahender.reddy@shristitech.com|2025-05-19|2025-06-02|2025-06-13|Vacation Leave 
Happy Shekh|happy.shekh@shristitech.com|2025-05-01|2025-05-08|2025-05-19|Vacation Leave 
Happy Shekh|happy.shekh@shristitech.com|2025-09-22|2025-10-07|2025-10-20|Vacation Leave 
Happy Shekh|happy.shekh@shristitech.com|2025-08-29|2025-09-10|2025-09-10|Sickness Leave 
Happy Shekh|happy.shekh@shristitech.com|2025-01-31|2025-02-03|2025-02-03|Sickness Leave 
Devender Singh|devender@shristitech.com|2025-03-31|2025-04-07|2025-04-25|Vacation Leave 
Devender Singh|devender@shristitech.com|2025-10-09|2025-10-22|2025-10-22|Sickness Leave 
Devender Singh|devender@shristitech.com|2025-01-18|2025-01-23|2025-01-23|Sickness Leave 
Devender Singh|devender@shristitech.com|2025-07-11|2025-07-17|2025-07-17|Sickness Leave 
Devender Singh|devender@shristitech.com|2025-10-29|2025-11-10|2025-11-10|Compassionate Leave
Mohammed Affan|mohammed.affan@shristitech.com|2025-11-03|2025-11-04|2025-12-31|Sickness Leave 
Sajan Ganeshmooprthy|sajan@shristitech.com|2025-01-20|2025-02-03|2025-02-14|Vacation Leave 
Sajan Ganeshmooprthy|sajan@shristitech.com|2025-05-09|2025-05-14|2025-05-23|Vacation Leave 
Sajan Ganeshmooprthy|sajan@shristitech.com|2025-07-20|2025-07-21|2025-07-23|Vacation Leave 
Shivani Pisati|shivani.p@shristitech.com|2025-11-26|2025-12-02|2025-12-04|Sickness Leave 
Sai Tharun|sai.tharun@shristitech.com|2025-12-11|2025-12-20|2025-12-31|Vacation Leave 
Sai Tharun|sai.tharun@shristitech.com|2025-08-08|2025-08-18|2025-08-29|Vacation Leave 
Sai Tharun|sai.tharun@shristitech.com|2025-04-10|2025-04-14|2025-04-25|Vacation Leave 
Radha Krishnaveni Pinisetti|radhakrishnaveni.p@shristitech.com|2025-12-10|2025-12-21|2026-01-04|Vacation Leave 
Radha Krishnaveni Pinisetti|radhakrishnaveni.p@shristitech.com|2025-09-07|2025-09-22|2025-09-26|Vacation Leave 
Arushi Guleria|arushi.guleria@shristitech.com|2025-07-21|2025-07-28|2025-08-15|Vacation Leave 
Riyaben Vrajesh Patel|riyaben@shristitech.com|2024-12-27|2025-01-06|2025-01-31|Vacation Leave 
Riyaben Vrajesh Patel|riyaben@shristitech.com|2025-10-14|2025-10-21|2025-10-30|Vacation Leave 
Riyaben Vrajesh Patel|riyaben@shristitech.com|2025-11-13|2025-11-17|2025-12-15|Vacation Leave 
Riyaben Vrajesh Patel|riyaben@shristitech.com|2025-03-09|2025-03-10|2025-03-12|Sickness Leave 
Riyaben Vrajesh Patel|riyaben@shristitech.com|2025-06-13|2025-06-18|2025-06-18|Vacation Leave 
Emad Uddin|emad.uddin@shristitech.com|2025-10-31|2025-11-03|2025-12-10|Vacation Leave 
Emad Uddin|emad.uddin@shristitech.com|2025-08-25|2025-09-08|2025-09-16|Vacation Leave 
Emad Uddin|emad.uddin@shristitech.com|2025-02-26|2025-03-03|2025-03-14|Vacation Leave 
Emad Uddin|emad.uddin@shristitech.com|2025-06-04|2025-06-18|2025-06-27|Vacation Leave 
Emad Uddin|emad.uddin@shristitech.com|2025-05-02|2025-05-06|2025-05-06|Sickness Leave 
Sireesh Kumar Suvarna|sireeshkumar.s@shristitech.com|2025-01-06|2025-01-13|2025-01-21|Vacation Leave 
EOF
)

ensure_mailbox_exists "$HR_MAILBOX"

body_text() {
  case "$1" in
    1) cat <<'EOF'
I need a long break from October 15 through December 10 to be in Sri Lanka with my parents while they handle some family matters. This was planned with them, and I’ll sort out handovers well before I leave. I’ll keep an eye on email for anything urgent.
EOF
    ;;
    2) cat <<'EOF'
I’d like a short vacation from November 17 to November 20 to spend a few days with my parents and reset before we start year-end deliverables. I’ll wrap up my tickets beforehand.
EOF
    ;;
    3) cat <<'EOF'
I’m requesting leave from February 17 to February 28 to attend a cousin’s wedding and stay a few extra days with family. I’ll finish my pending code reviews ahead of time.
EOF
    ;;
    4) cat <<'EOF'
I have a summer trip blocked from June 2 to June 13 that we booked months ago. I’ll hand over my sprint items before I go and remain reachable for anything critical.
EOF
    ;;
    5) cat <<'EOF'
Please approve leave from May 8 to May 19 so I can attend my sibling’s graduation and take a short holiday with family. I’ll ensure all deliverables are covered before I’m out.
EOF
    ;;
    6) cat <<'EOF'
I’m planning an extended family reunion and travel from October 7 to October 20. I’ll transition my tasks to the team and stay reachable for blockers.
EOF
    ;;
    7) cat <<'EOF'
I’m down with the flu and need a sick day on September 10. My doctor suggested resting and avoiding calls; I’ll be back the next day if all goes well.
EOF
    ;;
    8) cat <<'EOF'
I have a fever and need a sick day on February 3. I’ll rest per the clinic’s advice and return once the medication kicks in.
EOF
    ;;
    9) cat <<'EOF'
Please approve vacation from April 7 to April 25. I’m traveling for a family ceremony and a brief getaway. I’ll clear my open items before leaving.
EOF
    ;;
    10) cat <<'EOF'
Requesting a medical leave on October 22 for a scheduled health check. I’ll be back the following day and will finish today’s tasks before I log off.
EOF
    ;;
    11) cat <<'EOF'
I’m experiencing a bad migraine and need January 23 off to rest. I’ll catch up on pending work once I’m back.
EOF
    ;;
    12) cat <<'EOF'
I’ve picked up a seasonal fever and should stay home on July 17 to recover. I’ll reconnect as soon as I’m well.
EOF
    ;;
    13) cat <<'EOF'
I need compassionate leave on November 10 to support a close family member during a medical procedure. I’ll return the next day and cover any missed work.
EOF
    ;;
    14) cat <<'EOF'
My doctor has advised an extended recovery period from November 4 through December 31 due to ongoing treatment. I’ll share updates on progress and stay reachable for critical questions.
EOF
    ;;
    15) cat <<'EOF'
I’m requesting vacation from February 3 to February 14 to visit family during school holidays. I’ll complete my current tasks and share status notes before I go.
EOF
    ;;
    16) cat <<'EOF'
Please approve leave from May 14 to May 23 for a cousin’s wedding and related family events. I’ll hand off my work to ensure continuity.
EOF
    ;;
    17) cat <<'EOF'
I need a short break from July 21 to July 23 for personal commitments out of town. I’ll finish my deliverables before stepping away.
EOF
    ;;
    18) cat <<'EOF'
I’m feeling unwell and need sick leave from December 2 to December 4 to recover fully. I’ll check email periodically in case something urgent comes up.
EOF
    ;;
    19) cat <<'EOF'
Requesting year-end vacation from December 20 to December 31. Travel is booked with family, and I’ll wrap up my tasks before logging off.
EOF
    ;;
    20) cat <<'EOF'
I’m planning a festival trip to my hometown from August 18 to August 29. I’ll align with the team on coverage and leave clear notes.
EOF
    ;;
    21) cat <<'EOF'
I’d like vacation from April 14 to April 25 for a pre-planned trip with my parents. I’ll complete sprint commitments ahead of time.
EOF
    ;;
    22) cat <<'EOF'
Requesting leave from December 21 to January 4 for a year-end family meet-up and travel. I’ll coordinate a thorough handover before leaving.
EOF
    ;;
    23) cat <<'EOF'
I need vacation from September 22 to September 26 to visit relatives and wrap up some personal work. I’ll ensure my tasks are covered.
EOF
    ;;
    24) cat <<'EOF'
I’m requesting time off from July 28 to August 15 for a planned Himalayan trip with friends. I’ll finish my deliverables and hand over any pending items.
EOF
    ;;
    25) cat <<'EOF'
Please approve leave from January 6 to January 31 for an extended New Year break with family overseas. I’ll line up coverage and keep notes updated.
EOF
    ;;
    26) cat <<'EOF'
I plan to be away from October 21 to October 30 around the festival season to visit my hometown. I’ll prepare handovers and stay reachable for urgent questions.
EOF
    ;;
    27) cat <<'EOF'
Requesting extended leave from November 17 to December 15 to stay with family and help with some arrangements. I’ll provide detailed handover notes.
EOF
    ;;
    28) cat <<'EOF'
I’m unwell with a stomach infection and need sick leave from March 10 to March 12. I’ll rest per the doctor’s advice and return as soon as I’m better.
EOF
    ;;
    29) cat <<'EOF'
Kindly approve a one-day leave on June 18 for a family function. I’ll complete my tasks in advance.
EOF
    ;;
    30) cat <<'EOF'
Requesting vacation from November 3 to December 10 for a long-planned overseas trip with family. I’ll hand over my work and keep Slack on for emergencies.
EOF
    ;;
    31) cat <<'EOF'
I’d like leave from September 8 to September 16 to visit my parents and sort some personal errands. I’ll coordinate coverage before I go.
EOF
    ;;
    32) cat <<'EOF'
Please approve time off from March 3 to March 14 to attend a close friend’s wedding and spend a few days with family. I’ll finish my sprint items beforehand.
EOF
    ;;
    33) cat <<'EOF'
I’m planning travel from June 18 to June 27 for a family reunion and short break. I’ll share a clear handover before leaving.
EOF
    ;;
    34) cat <<'EOF'
Requesting a sick day on May 6 after a doctor’s check-up. I need the day to rest and recover fully.
EOF
    ;;
    35) cat <<'EOF'
I’d like vacation from January 13 to January 21 for a family trip aligned with school schedules. I’ll close out my tasks and leave notes for the team.
EOF
    ;;
  esac
}

TRANSACTION_ROWS=$(cat <<EOF
1	2025-01-04 09:30	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Invoice for Professional Services | INV-IM-010425
2	2025-01-29 10:45	Accounts Team	$INSTA_EMAIL	HR Team	$HR_MAILBOX	Payment Confirmation | INV-IM-010425
3	2025-01-29 15:30	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Payment Received - Thank You | INV-IM-010425
4	2025-03-05 10:00	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Invoice Issued for Services Rendered | INV-IM-030525
5	2025-03-24 11:10	Accounts Team	$INSTA_EMAIL	HR Team	$HR_MAILBOX	Payment Intimation | INV-IM-030525
6	2025-03-24 16:05	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Payment Acknowledgement | INV-IM-030525
7	2025-08-12 09:40	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Invoice Raised as per Agreement | INV-IM-081225
8	2025-09-02 10:50	Accounts Team	$INSTA_EMAIL	HR Team	$HR_MAILBOX	Payment Processed | INV-IM-081225
9	2025-09-02 15:20	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Payment Received Confirmation | INV-IM-081225
10	2025-06-15 10:15	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Invoice for Professional Services | INV-PS-061525
11	2025-07-01 11:05	Accounts Team	$PRAYAG_EMAIL	HR Team	$HR_MAILBOX	Payment Confirmation | INV-PS-061525
12	2025-07-01 15:40	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Payment Acknowledged | INV-PS-061525
13	2025-07-20 09:25	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Invoice Issued for Services | INV-PS-072025-01
14	2025-07-31 10:30	Accounts Team	$PRAYAG_EMAIL	HR Team	$HR_MAILBOX	Payment Intimation | INV-PS-072025-01
15	2025-07-31 16:10	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Payment Received | INV-PS-072025-01
16	2025-07-20 11:00	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Invoice Issued for Services | INV-PS-072025-02
17	2025-07-31 12:00	Accounts Team	$PRAYAG_EMAIL	HR Team	$HR_MAILBOX	Payment Confirmation | INV-PS-072025-02
18	2025-07-31 17:00	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Payment Acknowledged | INV-PS-072025-02
19	2025-12-28 10:10	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Invoice Issued for Professional Services | INV-IM-122825
20	2026-01-10 11:20	HR Team	$HR_MAILBOX	Insta Minerals Team	$INSTA_EMAIL	Follow-Up on Pending Invoice | INV-IM-122825
21	2026-01-12 14:30	Accounts Team	$INSTA_EMAIL	HR Team	$HR_MAILBOX	Re: Follow-Up on Pending Invoice | INV-IM-122825
22	2025-08-20 10:25	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Invoice Issued for Services | INV-PS-082025
23	2025-09-05 11:15	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Pending Invoice Reminder | INV-PS-082025
24	2025-09-07 14:10	Accounts Team	$PRAYAG_EMAIL	HR Team	$HR_MAILBOX	Re: Pending Invoice Reminder | INV-PS-082025
25	2025-09-21 09:50	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Invoice Raised as per Agreement | INV-PS-092125
26	2025-10-06 11:05	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Follow-Up on Outstanding Invoice | INV-PS-092125
27	2025-10-08 15:25	Accounts Team	$PRAYAG_EMAIL	HR Team	$HR_MAILBOX	Re: Follow-Up on Outstanding Invoice | INV-PS-092125
28	2025-10-18 10:35	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Invoice for Professional Services | INV-PS-101825
29	2025-11-03 11:10	HR Team	$HR_MAILBOX	Prayag Solutions Team	$PRAYAG_EMAIL	Pending Invoice Follow-Up | INV-PS-101825
30	2025-11-05 14:45	Accounts Team	$PRAYAG_EMAIL	HR Team	$HR_MAILBOX	Re: Pending Invoice Follow-Up | INV-PS-101825
EOF
)

transaction_body_text() {
  case "$1" in
    1) cat <<'EOF'
Dear Insta Minerals Team,
Greetings from Shristi Tech.
We hope you are doing well.
Please find the invoice raised for the professional services rendered as per our agreed terms. We request you to kindly review the invoice details and reach out to us in case any clarification or additional information is required.
For your reference, the invoice document can be accessed using the link below:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-IM-010425.pdf
We appreciate your continued association and look forward to your confirmation.
Warm regards,
HR Team
Shristi Tech
hr@shristitech.com
EOF
    ;;
    2) cat <<'EOF'
Dear HR Team,
This is to inform you that the payment for the referenced invoice has been successfully processed from our end.
Kindly acknowledge receipt once the payment is reflected in your records. Please let us know if any additional details are required.
Best regards,
Accounts Team
Insta Minerals
EOF
    ;;
    3) cat <<'EOF'
Dear Insta Minerals Team,
Thank you for your email.
We confirm that the payment against the referenced invoice has been received and duly recorded in our system.
We appreciate your timely cooperation and look forward to continuing our professional engagement.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    4) cat <<'EOF'
Dear Insta Minerals Team,
Greetings from Shristi Tech.
Please find the invoice raised for services delivered during the applicable period, in line with our agreement. We request you to review the details and share your confirmation.
The invoice document is available at the link below for your convenience:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-IM-030525.pdf
Should you require any clarification, please feel free to contact us.
Warm regards,
HR Team
Shristi Tech
EOF
    ;;
    5) cat <<'EOF'
Dear HR Team,
We would like to inform you that payment for the above invoice has been completed from our side.
Please acknowledge once the payment is reflected at your end.
Regards,
Accounts Team
Insta Minerals
EOF
    ;;
    6) cat <<'EOF'
Dear Insta Minerals Team,
We acknowledge receipt of the payment for the referenced invoice.
Thank you for the prompt settlement. We value our association and look forward to working together.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    7) cat <<'EOF'
Dear Insta Minerals Team,
Greetings from Shristi Tech.
As discussed, please find the invoice raised for the services provided. We request you to review the same and confirm if everything is in order.
The invoice document can be accessed using the link below:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-IM-081225.pdf
Thank you for your cooperation.
Warm regards,
HR Team
Shristi Tech
EOF
    ;;
    8) cat <<'EOF'
Dear HR Team,
This is to inform you that the payment for the referenced invoice has been successfully processed.
Kindly confirm receipt.
Regards,
Accounts Team
Insta Minerals
EOF
    ;;
    9) cat <<'EOF'
Dear Insta Minerals Team,
We confirm receipt of the payment for the referenced invoice.
Thank you for your continued support and timely processing.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    10) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
Please find the invoice raised for the professional services rendered as per our agreement. We request you to review the invoice details and share your confirmation.
The invoice document is available at the link below for your reference:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-PS-061525.pdf
We appreciate your continued association.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    11) cat <<'EOF'
Dear HR Team,
This is to confirm that payment for the mentioned invoice has been completed from our end.
Please acknowledge once received.
Regards,
Accounts Team
Prayag Solutions
EOF
    ;;
    12) cat <<'EOF'
Dear Prayag Solutions Team,
We acknowledge receipt of the payment for the referenced invoice.
Thank you for the prompt settlement and continued cooperation.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    13) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
Please find the invoice raised for services delivered during the applicable period. We request you to review the details and let us know if any clarification is required.
Invoice document link for your convenience:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-PS-072025-01.pdf
Thank you for your continued partnership.
Warm regards,
HR Team
Shristi Tech
EOF
    ;;
    14) cat <<'EOF'
Dear HR Team,
This is to inform you that payment for the referenced invoice has been processed successfully.
Kindly acknowledge receipt.
Regards,
Accounts Team
Prayag Solutions
EOF
    ;;
    15) cat <<'EOF'
Dear Prayag Solutions Team,
We confirm receipt of the payment for the referenced invoice.
Thank you for your cooperation.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    16) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
Please find the invoice raised for additional services provided as per our agreement. We request you to review and confirm the details.
Invoice document link:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-PS-072025-02.pdf
We appreciate your continued support.
Warm regards,
HR Team
Shristi Tech
EOF
    ;;
    17) cat <<'EOF'
Dear HR Team,
This is to inform you that payment for the above invoice has been completed from our side.
Please confirm receipt.
Regards,
Accounts Team
Prayag Solutions
EOF
    ;;
    18) cat <<'EOF'
Dear Prayag Solutions Team,
We acknowledge receipt of the payment for the referenced invoice.
Thank you for the timely processing.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    19) cat <<'EOF'
Dear Insta Minerals Team,
Greetings from Shristi Tech.
We hope you are doing well.
Please find the invoice raised for the professional services rendered as per our agreement. We request you to kindly review the invoice details and let us know if any clarification or additional information is required.
For your reference, the invoice document can be accessed using the link below:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-IM-122825.pdf
We appreciate your continued association and look forward to your confirmation.
Warm regards,
HR Team
Shristi Tech
hr@shristitech.com
EOF
    ;;
    20) cat <<'EOF'
Dear Insta Minerals Team,
Greetings from Shristi Tech.
We are writing to follow up on the invoice shared earlier, which is currently pending at our end. We request you to kindly review the same and share an update regarding the payment status.
Please let us know if there are any concerns or additional details required from our side to facilitate the processing.
We appreciate your support and look forward to your response.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    21) cat <<'EOF'
Dear HR Team,
Thank you for your follow-up.
We would like to inform you that the payment for the referenced invoice is currently under internal review and approval. There has been a slight delay due to administrative processing at our end.
We expect the payment to be processed shortly and will keep you informed of the progress.
Thank you for your understanding.
Best regards,
Accounts Team
Insta Minerals
EOF
    ;;
    22) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
Please find the invoice raised for services rendered as per our agreement. We request you to review the invoice details and confirm if everything is in order.
The invoice document is available at the link below for your reference:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-PS-082025.pdf
Thank you for your continued association.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    23) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
This is a gentle reminder regarding the invoice shared earlier, which is currently pending payment. We kindly request you to share an update on the status.
Please let us know if any clarification or documentation is required from our end.
Looking forward to your response.
Warm regards,
HR Team
Shristi Tech
EOF
    ;;
    24) cat <<'EOF'
Dear HR Team,
Thank you for reaching out.
We would like to inform you that the payment is pending internal approval due to month-end processing. There has been a slight delay from our side.
We expect the payment to be processed soon and will notify you once completed.
Regards,
Accounts Team
Prayag Solutions
EOF
    ;;
    25) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
As discussed, please find the invoice raised for services delivered during the applicable period. We request you to review the same and confirm.
Invoice document link:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-PS-092125.pdf
Thank you for your cooperation.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    26) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
We are following up on the invoice shared earlier, which remains outstanding. We kindly request an update on the expected payment timeline.
Please feel free to reach out if you need any assistance from our side.
Warm regards,
HR Team
Shristi Tech
EOF
    ;;
    27) cat <<'EOF'
Dear HR Team,
Thank you for your message.
The payment for the referenced invoice has been delayed due to budget reconciliation on our end. We are working on resolving this internally.
We appreciate your patience and will keep you posted.
Best regards,
Accounts Team
Prayag Solutions
EOF
    ;;
    28) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
Please find the invoice raised for professional services rendered as per agreed terms. We request you to review and confirm.
Invoice link for reference:
https://shristitech.sharepoint.com/sites/Finance/Shared%20Documents/Invoices/2025/INV-PS-101825.pdf
Thank you for your continued cooperation.
Best regards,
HR Team
Shristi Tech
EOF
    ;;
    29) cat <<'EOF'
Dear Prayag Solutions Team,
Greetings from Shristi Tech.
We are writing to follow up on the pending invoice shared earlier. Kindly provide an update on the payment status.
Please let us know if any additional details are required from our end.
Warm regards,
HR Team
Shristi Tech
EOF
    ;;
    30) cat <<'EOF'
Dear HR Team,
Thank you for the follow-up.
There has been a delay due to internal approval workflows. The payment is expected to be processed shortly.
We appreciate your understanding.
Regards,
Accounts Team
Prayag Solutions
EOF
    ;;
  esac
}

# Prepare temporary Maildir for Inbox (requests are from employees to HR)
MAILDIR_INBOX=$(mktemp -d /tmp/hr-leave-inbox.XXXXXX)
mkdir -p "$MAILDIR_INBOX"/{cur,new,tmp}

msg_counter=1
while IFS='|' read -r NAME EMAIL REQ START END TYPE ATTACHMENT_PATH; do
  [[ -z "$NAME" || "$NAME" == "Name" ]] && continue

  # Build unique subject per entry
  SUBJECT="$TYPE request"

  # Base epoch is the request date
  EPOCH_BASE=$(python3 - <<PY
from datetime import datetime, timezone
print(int(datetime.fromisoformat("$REQ").replace(tzinfo=timezone.utc).timestamp()))
PY
)

  EPOCH_SEND=$(randomize_epoch_workhours "$EPOCH_BASE")
  DATE_HEADER=$(epoch_to_rfc2822 "$EPOCH_SEND")
  TOUCH_TS=$(epoch_to_touch "$EPOCH_SEND")

  # Message-ID
  MSG_ID=$(printf "<leave-%03d@%s>" "$msg_counter" "$MSG_DOMAIN")

  purge_existing_message "$MSG_ID"

  BODY_CONTENT=$(body_text "$msg_counter")
  ATTACHMENT_PATH=$(resolve_attachment_path "$ATTACHMENT_PATH")

  FILE_PATH="$MAILDIR_INBOX/new/${EPOCH_SEND}.M$$.$msg_counter.msg"
  FULL_BODY=$(cat <<EOF
Dear HR Team,

$BODY_CONTENT

Thank you for considering this request.

Best regards,
$NAME
EOF
)
  write_message \
    "$FILE_PATH" \
    "$NAME <$EMAIL>" \
    "$HR_MAILBOX" \
    "$SUBJECT" \
    "$DATE_HEADER" \
    "$MSG_ID" \
    "$FULL_BODY" \
    "$ATTACHMENT_PATH"
  touch -t "$TOUCH_TS" "$FILE_PATH"
  msg_counter=$((msg_counter + 1))
done <<< "$EMAIL_ROWS"

# Copy Maildir into container and import to Inbox
CONTAINER_INBOX="/tmp/hr-leave-inbox.$$"
docker cp "$MAILDIR_INBOX" "$CONTAINER_NAME:$CONTAINER_INBOX"
docker exec "$CONTAINER_NAME" chown -R vmail:vmail "$CONTAINER_INBOX"

docker exec "$CONTAINER_NAME" \
  doveadm import -u "$HR_MAILBOX" "maildir:${CONTAINER_INBOX}" INBOX ALL

# Normalize folder placement (avoid INBOX/INBOX artifacts)
docker exec "$CONTAINER_NAME" doveadm move -u "$HR_MAILBOX" INBOX mailbox "INBOX/INBOX" all >/dev/null 2>&1 || true

# Cleanup
docker exec "$CONTAINER_NAME" rm -rf "$CONTAINER_INBOX"
rm -rf "$MAILDIR_INBOX"

echo "✔ Seeded leave requests into Inbox for $HR_MAILBOX"

# Prepare temporary Maildir for Inbox (invoice/payment threads)
MAILDIR_FINANCE=$(mktemp -d /tmp/hr-finance-inbox.XXXXXX)
mkdir -p "$MAILDIR_FINANCE"/{cur,new,tmp}

finance_counter=1
while IFS=$'\t' read -r BODY_ID DATE_TIME FROM_NAME FROM_EMAIL TO_NAME TO_EMAIL SUBJECT ATTACHMENT_PATH; do
  [[ -z "$BODY_ID" || "$BODY_ID" == "ID" ]] && continue

  EPOCH_SEND=$(datetime_to_epoch "$DATE_TIME")
  DATE_HEADER=$(epoch_to_rfc2822 "$EPOCH_SEND")
  TOUCH_TS=$(epoch_to_touch "$EPOCH_SEND")

  MSG_ID=$(printf "<finance-%03d@%s>" "$finance_counter" "$MSG_DOMAIN")

  purge_existing_message "$MSG_ID"

  BODY_CONTENT=$(transaction_body_text "$BODY_ID")
  ATTACHMENT_PATH=$(resolve_attachment_path "$ATTACHMENT_PATH")

  FILE_PATH="$MAILDIR_FINANCE/new/${EPOCH_SEND}.M$$.$finance_counter.msg"
  write_message \
    "$FILE_PATH" \
    "$FROM_NAME <$FROM_EMAIL>" \
    "$TO_NAME <$TO_EMAIL>" \
    "$SUBJECT" \
    "$DATE_HEADER" \
    "$MSG_ID" \
    "$BODY_CONTENT" \
    "$ATTACHMENT_PATH"
  touch -t "$TOUCH_TS" "$FILE_PATH"
  finance_counter=$((finance_counter + 1))
done <<< "$TRANSACTION_ROWS"

# Copy Maildir into container and import to Inbox
CONTAINER_FINANCE="/tmp/hr-finance-inbox.$$"
docker cp "$MAILDIR_FINANCE" "$CONTAINER_NAME:$CONTAINER_FINANCE"
docker exec "$CONTAINER_NAME" chown -R vmail:vmail "$CONTAINER_FINANCE"

docker exec "$CONTAINER_NAME" \
  doveadm import -u "$HR_MAILBOX" "maildir:${CONTAINER_FINANCE}" INBOX ALL

# Normalize folder placement (avoid INBOX/INBOX artifacts)
docker exec "$CONTAINER_NAME" doveadm move -u "$HR_MAILBOX" INBOX mailbox "INBOX/INBOX" all >/dev/null 2>&1 || true

# Cleanup
docker exec "$CONTAINER_NAME" rm -rf "$CONTAINER_FINANCE"
rm -rf "$MAILDIR_FINANCE"

echo "✔ Seeded invoice and payment threads into Inbox for $HR_MAILBOX"
