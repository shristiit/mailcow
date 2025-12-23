#!/bin/bash

MAILBOXES=(
  "raghu.bezawada@shristitech.com"
  "saikrishnareddymalla@stockaisle.onmicrosoft.com"
)

for MAILBOX in "${MAILBOXES[@]}"; do
  EMAIL_FILE=$(mktemp /tmp/custom-email-XXXXXX.eml)

  echo "Creating email file for $MAILBOX..."

  cat <<EOF > "$EMAIL_FILE"
From: Saikrishna Reddy Malla <SAIKRISHNAREDDYMALLA@Stockaisle.onmicrosoft.com>
To: $MAILBOX
Subject: Verify the server
Date: Wed, 01 Dec 2021 10:00:00 +0000
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY456"

--BOUNDARY456
Content-Type: text/plain; charset="UTF-8"

Please verify the server configuration.

--BOUNDARY456
Content-Type: text/plain; name="info.txt"
Content-Disposition: attachment; filename="info.txt"
Content-Transfer-Encoding: base64

$(echo "This is a verification attachment generated for server testing." | base64)

--BOUNDARY456--
EOF

  echo "Copying email into container..."
  docker cp "$EMAIL_FILE" mailcowdockerized-dovecot-mailcow-1:/tmp/custom-email-2.eml

  echo "Saving email into INBOX for $MAILBOX..."
  docker exec -i mailcowdockerized-dovecot-mailcow-1 sh -c \
  "cat /tmp/custom-email-2.eml | doveadm save -u $MAILBOX -m INBOX -"

  echo "Cleaning up temp file..."
  docker exec mailcowdockerized-dovecot-mailcow-1 rm /tmp/custom-email-2.eml
  rm "$EMAIL_FILE"

  echo "✔ DONE — Email delivered to $MAILBOX"
done
