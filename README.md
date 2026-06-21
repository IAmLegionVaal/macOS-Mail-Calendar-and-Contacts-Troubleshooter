# macOS Mail, Calendar and Contacts Troubleshooter

A macOS support toolkit for diagnosing and repairing common Mail, Calendar, Contacts and account-sync problems.

## Diagnostic script

```bash
chmod +x src/mail_calendar_contacts_troubleshooter.sh
./src/mail_calendar_contacts_troubleshooter.sh --hours 24
```

The diagnostic script checks processes, application data, database metadata, account indicators, recent events and optional IMAP or SMTP reachability.

## Repair script

Preview the repair:

```bash
chmod +x src/mail_calendar_contacts_repair.sh
./src/mail_calendar_contacts_repair.sh --repair --dry-run
```

Apply the repair:

```bash
./src/mail_calendar_contacts_repair.sh --repair
```

Apply the repair and reopen the applications:

```bash
./src/mail_calendar_contacts_repair.sh --repair --launch-apps
```

## What the repair does

- Gracefully closes Mail, Calendar and Contacts when they are running.
- Restarts the Apple account, Calendar and Contacts background agents when present.
- Allows macOS to relaunch the background agents on demand.
- Optionally reopens Mail, Calendar and Contacts.
- Writes a repair log and a post-repair verification report.
- Returns a success or warning exit code.

## Safety

The repair does not remove accounts, messages, calendars, contacts or passwords. It does not delete application databases. Issues caused by damaged databases, incorrect account details or provider-side outages may still need manual intervention.

## Privacy

Diagnostic reports redact obvious email addresses but can still contain server names, file paths and account metadata. Review reports before sharing them.

## Author

Dewald Pretorius — L2 IT Support Engineer
