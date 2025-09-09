# Local Mail Server with Postfix, Dovecot, and Outlook (Classic)

This project sets up a **local IMAP/SMTP mail server** on Ubuntu using **Postfix** and **Dovecot**, and connects it to **Outlook (classic)**.
It uses **one single Ubuntu user** (`lakhan-kumar`) for both sending and receiving mail.

---

## Installation

```bash
sudo apt update
sudo apt install -y postfix dovecot-imapd dovecot-pop3d mailutils openssl
```

During Postfix setup:

* Choose **Internet Site**
* Set system mail name: `localhost.localdomain`

---

## Postfix Configuration

### Identity

```bash
sudo postconf -e 'myhostname = mail.localhost'
sudo postconf -e 'mydomain = localhost.localdomain'
sudo postconf -e 'myorigin = $mydomain'
sudo postconf -e 'mydestination = $myhostname, localhost, $mydomain'
sudo postconf -e 'home_mailbox = Maildir/'
```

### TLS Certificates

```bash
sudo mkdir -p /etc/ssl/local && cd /etc/ssl/local
sudo openssl req -new -x509 -days 365 -nodes \
  -out mail.localhost.crt -keyout mail.localhost.key \
  -subj "/CN=mail.localhost"

sudo cp mail.localhost.crt /etc/ssl/certs/
sudo cp mail.localhost.key /etc/ssl/private/
sudo chgrp ssl-cert /etc/ssl/private/mail.localhost.key
sudo chmod 640 /etc/ssl/private/mail.localhost.key
sudo usermod -aG ssl-cert postfix
sudo usermod -aG ssl-cert dovecot
```

```bash
sudo postconf -e 'smtpd_tls_cert_file = /etc/ssl/certs/mail.localhost.crt'
sudo postconf -e 'smtpd_tls_key_file = /etc/ssl/private/mail.localhost.key'
sudo postconf -e 'smtpd_tls_security_level = may'
sudo postconf -e 'smtpd_tls_loglevel = 1'
```

### Submission service (port 587)

Edit `/etc/postfix/master.cf` and ensure:

```conf
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

### SASL auth (via Dovecot)

```bash
sudo postconf -e 'smtpd_sasl_type = dovecot'
sudo postconf -e 'smtpd_sasl_path = private/auth'
sudo postconf -e 'smtpd_sasl_auth_enable = yes'
sudo postconf -e 'smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination'
```

---

## Dovecot Configuration

### Mail location — `/etc/dovecot/conf.d/10-mail.conf`

```conf
mail_location = maildir:~/Maildir
mail_privileged_group = mail
first_valid_uid = 1000

namespace inbox {
  inbox = yes
  prefix =
  separator = /

  mailbox Drafts {
    auto = create
    special_use = \Drafts
  }
  mailbox Sent {
    auto = create
    special_use = \Sent
  }
  mailbox Trash {
    auto = create
    special_use = \Trash
  }
  mailbox Junk {
    auto = create
    special_use = \Junk
  }
}
```

### Auth — `/etc/dovecot/conf.d/10-auth.conf`

```conf
disable_plaintext_auth = yes
auth_username_format = %n
auth_mechanisms = plain login
!include auth-system.conf.ext
```

### SSL — `/etc/dovecot/conf.d/10-ssl.conf`

```conf
ssl = yes
ssl_cert = </etc/ssl/certs/mail.localhost.crt
ssl_key  = </etc/ssl/private/mail.localhost.key
ssl_min_protocol = TLSv1.2
```

### Master (Postfix SASL socket) — `/etc/dovecot/conf.d/10-master.conf`

```conf
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}

service auth {
  unix_listener auth-userdb {
    mode = 0600
    user = dovecot
    group = dovecot
  }
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}

service auth-worker {
  user = root
}
```

---

## Maildir Setup

For the **default user (`lakhan-kumar`)**:

```bash
maildirmake.dovecot ~/Maildir
maildirmake.dovecot ~/Maildir/.Drafts
maildirmake.dovecot ~/Maildir/.Sent
maildirmake.dovecot ~/Maildir/.Trash
maildirmake.dovecot ~/Maildir/.Junk
```

---

## Restart Services

```bash
sudo systemctl restart postfix
sudo systemctl restart dovecot
```

Check status:

```bash
systemctl status postfix --no-pager
systemctl status dovecot --no-pager
```

---

## Outlook (Classic) Configuration

1. Add account → Manual setup (IMAP).
2. Settings:

**Incoming mail (IMAP):**

* Server: `mail.localhost`
* Port: `993`
* Encryption: **SSL/TLS**
* Username: `lakhan-kumar`
* Password: your Ubuntu password

**Outgoing mail (SMTP):**

* Server: `mail.localhost`
* Port: `587`
* Encryption: **STARTTLS**
* Outgoing server requires authentication: ✅
* Username: `lakhan-kumar`
* Password: same as above

3. Accept self-signed certificate warning.
4. Click **Send/Receive All Folders** (F9) to sync.

---

## Add Additional Users

### Add a Test User

```bash
# --- Create user alice ---
sudo useradd -m -s /bin/bash alice
echo "alice:<password>" | sudo chpasswd

# Maildir for alice
sudo -u alice maildirmake.dovecot /home/alice/Maildir
sudo -u alice maildirmake.dovecot /home/alice/Maildir/.Drafts
sudo -u alice maildirmake.dovecot /home/alice/Maildir/.Sent
sudo -u alice maildirmake.dovecot /home/alice/Maildir/.Trash
sudo -u alice maildirmake.dovecot /home/alice/Maildir/.Junk
sudo chown -R alice:alice /home/alice/Maildir
```

### Test Authentication

```bash
sudo doveadm auth test 'alice' '<passwd>'
```

#### Expected output:
```bash
passdb: alice auth succeeded
```

### Outlook (Classic) Configuration for User Alice

* Email: `alice@localhost.localdomain`
* IMAP server: mail.localhost — port 993 — SSL/TLS
* SMTP server: mail.localhost — port 587 — STARTTLS
* Username: alice
* Password: <passwd>

---

## Change Hostname to localhost.localdomain

You’re seeing **`alice@Lakhan-Kumar`** because the message was sent locally (via `mail` / GNU mailutils), which by default builds the sender as:

```
<linux-username>@<machine-hostname>
```

The hostname is **`Lakhan-Kumar`**, so the envelope sender becomes `alice@Lakhan-Kumar`. Postfix will accept that as-is unless you tell it to **rewrite** local sender addresses to your preferred domain (**`localhost.localdomain`**).

You already set:

* `myhostname = mail.localhost`
* `mydomain   = localhost.localdomain`
* `myorigin   = $mydomain`

but those only help when the sender is just `alice` (no `@domain`). Since mailutils gives Postfix a *fully qualified* sender (`alice@Lakhan-Kumar`), Postfix does **not** override it automatically.

### Rewrite all local senders to `@localhost.localdomain`

1. Install PCRE maps:

```bash
sudo apt update
sudo apt install -y postfix-pcre
```

2. Create a sender canonical map that rewrites any `user@anything` to `user@localhost.localdomain`:

```bash
sudo tee /etc/postfix/sender_canonical.pcre >/dev/null <<'EOF'
/^([^@]+)@.*/     ${1}@localhost.localdomain
EOF
```

3. Update and Relod Postifx:

```bash
sudo postconf -e 'sender_canonical_maps = pcre:/etc/postfix/sender_canonical.pcre'
sudo systemctl reload postfix
```

4. Test:

```bash
echo "Hello" | mail -s "Test rewrite" alice@localhost.localdomain
sudo tail -n 30 /var/log/mail.log
# Then open the new file in ~/Maildir/new and check:
# Return-Path: <alice@localhost.localdomain>
# From: alice@localhost.localdomain
```

## Debugging & Verification

### Service status

```bash
systemctl status postfix
systemctl status dovecot
```

### Logs

```bash
sudo tail -f /var/log/mail.log
sudo journalctl -fu dovecot
```

### Check open ports

```bash
sudo ss -lntp | egrep ':(25|587|143|993)\b'
```

### Send test mail (Ubuntu → Outlook)

```bash
echo "Hello from Ubuntu" | mail -s "Inbox test" lakhan-kumar@localhost.localdomain
ls -l ~/Maildir/new
```

### Test auth

```bash
sudo doveadm auth test 'lakhan-kumar' 'your_password'
```

### Test IMAP manually

```bash
openssl s_client -connect mail.localhost:993 -quiet
a login lakhan-kumar your_password
```

### Test SMTP manually

```bash
openssl s_client -starttls smtp -connect mail.localhost:587 -crlf -quiet
EHLO x
```

---

## Common Fixes

* **Remove Windows CRLF or BOM from configs**
  (fixes “garbage after {” errors):

  ```bash
  sudo sed -i 's/\r$//' /etc/dovecot/conf.d/10-mail.conf
  sudo sed -i '1s/^\xEF\xBB\xBF//' /etc/dovecot/conf.d/10-mail.conf
  ```

* **Postfix chroot DNS issues**

  ```bash
  sudo mkdir -p /var/spool/postfix/etc
  sudo cp /etc/hosts /etc/resolv.conf /etc/services /var/spool/postfix/etc/
  ```

* **Auth worker must run as root (for PAM)**
  In `/etc/dovecot/conf.d/10-master.conf`:

  ```conf
  service auth-worker {
    user = root
  }
  ```

---

## Verification

* `doveadm auth test` → `auth succeeded`
* Outlook shows **Connected** (bottom right)
* Sending mail in Outlook delivers to `~/Maildir`
* Maildir messages sync back to Outlook Inbox

---
