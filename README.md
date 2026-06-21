# macOS Mail, Calendar and Contacts Troubleshooter

A read-only Bash toolkit for collecting Mail, Calendar, Contacts, internet-account, database, process, connectivity, and recent sync-event evidence.

## Usage

```bash
chmod +x src/mail_calendar_contacts_troubleshooter.sh
./src/mail_calendar_contacts_troubleshooter.sh --hours 24
```

## Checks performed

- Mail, Calendar, Contacts, accountsd, and sync processes
- Application data and database sizes
- Internet account indicators with email addresses redacted
- Mail queue and envelope-index metadata
- Recent Mail, Calendar, Contacts, account, IMAP, SMTP, and sync events
- Optional IMAP and SMTP host reachability tests
- Text, CSV, and JSON reports

## Safety

The script does not send mail, modify accounts, rebuild databases, clear caches, remove messages, or change passwords.

## Privacy

Reports redact obvious email addresses but can still contain server names, file paths, and account metadata. Review before sharing.

## Author

Dewald Pretorius — L2 IT Support Engineer
