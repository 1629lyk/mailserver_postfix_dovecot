# Postfix + Dovecot SMTP/IMAP Server in Docker

## 📌 Project Overview
This project sets up a **self-hosted email server** using **Postfix** (SMTP) and **Dovecot** (IMAP) inside a Docker container running on **Ubuntu** (inside a VM).  
The goal is to allow creation of local system users who can log in to email clients like **Outlook** to send and receive mail securely over SSL/TLS.

---

## 🖥️ Required Shell Commands

### **Build the image**

```bash
docker build -t secure-mailserver .
```

### **Run the container**

```bash
docker run -d --name mailserver \
  -p 587:587 -p 993:993 \
  --hostname mail.local --privileged secure-mailserver
```

### **Check running containers**

```bash
docker ps
```

### **Access container shell**

```bash
docker exec -it mailserver bash
```

### **View logs**

```bash
tail -f /var/log/mail.log
```

### **Check listening ports**

```bash
netstat -tulnp | grep -E '587|993'
```

---

## 📧 Outlook Configuration

| Field          | Value                  |
| -------------- | ---------------------- |
| Email address  | `bobuser@mail.local`   |
| Username       | `bobuser`              |
| Password       | `bobtestpass`          |
| IMAP Server    | `192.168.1.131`        |
| IMAP Port      | 993 (SSL/TLS)          |
| SMTP Server    | `192.168.1.131`        |
| SMTP Port      | 587 (STARTTLS)         |
| Requires Auth? | Yes (same credentials) |

---

## ⚠️ Current Problem

I am currently facing an **authentication failure** when trying to log in via Outlook.
Outlook reports:

```
InvalidCredentials
temporarilyunavailable
```

### 🔍 Observations:

* Ports 587 (SMTP) and 993 (IMAP) are accessible from the Windows host
* TLS handshake completes, but authentication fails
* Likely causes:

  * Outlook is sending `bobuser@mail.local` instead of `bobuser`
  * Dovecot authentication misconfiguration
  * Password mismatch with system user

### 📌 Next Steps to Resolve:

1. Confirm `bobuser` exists and password is correct:

   ```bash
   id bobuser
   echo "bobuser:bobtestpass" | chpasswd
   ```
2. Ensure `/etc/dovecot/conf.d/10-auth.conf` contains:

   ```conf
   auth_username_format = %n
   !include auth-system.conf.ext
   ```
3. Enable verbose logging in Dovecot to capture authentication attempts:

   ```conf
   auth_verbose = yes
   auth_debug = yes
   auth_debug_passwords = yes
   ```
4. Monitor `/var/log/mail.log` while attempting Outlook login.

---

