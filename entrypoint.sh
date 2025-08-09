#!/bin/bash

#  Postfix Configuration 
postconf -e "home_mailbox = Maildir/"
postconf -e "myhostname = mail.local"
postconf -e "mydestination = \$myhostname, localhost"
postconf -e "inet_interfaces = all"
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_sasl_security_options = noanonymous"
postconf -e "smtpd_tls_cert_file = /etc/ssl/certs/mailcert.pem"
postconf -e "smtpd_tls_key_file = /etc/ssl/private/mailkey.pem"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_auth_only = yes"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtp_tls_security_level = may"
postconf -e "broken_sasl_auth_clients = yes"
postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination"

#  Create User: bobuser 
useradd -m bobuser
echo "bobuser:bobtestpass" | chpasswd
mkdir -p /home/bobuser/Maildir/{cur,new,tmp}
chown -R bobuser:bobuser /home/bobuser/Maildir

#  TLS: Self-Signed Certificates 
mkdir -p /etc/ssl/private
openssl req -new -x509 -days 3650 -nodes \
  -out /etc/ssl/certs/mailcert.pem \
  -keyout /etc/ssl/private/mailkey.pem \
  -subj "/C=US/ST=Mail/L=Mail/O=Mailserver/OU=IT/CN=mail.local"

#  Dovecot Configuration 

# Mail location
cat > /etc/dovecot/conf.d/10-mail.conf <<EOF
mail_location = maildir:~/Maildir
mail_privileged_group = mail
EOF

# Auth mechanism
cat > /etc/dovecot/conf.d/10-auth.conf <<EOF
disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-system.conf.ext
EOF

# Socket for Postfix SASL
cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

# SSL settings
cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
ssl = required
ssl_cert = </etc/ssl/certs/mailcert.pem
ssl_key = </etc/ssl/private/mailkey.pem
EOF

#  Start Services ──
service postfix start
service dovecot start

#  Keep Container Running 
tail -f /dev/null
