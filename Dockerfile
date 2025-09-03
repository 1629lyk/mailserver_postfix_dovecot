FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    postfix \
    dovecot-core dovecot-imapd dovecot-pop3d \
    mailutils \
    libsasl2-modules \
    ca-certificates \
    openssl \
    vim \
    net-tools

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 587 993

CMD ["bash"]

