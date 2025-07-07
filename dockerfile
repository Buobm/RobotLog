# Dockerfile
FROM mcr.microsoft.com/mssql/server:2022-latest

USER root
# install the SQLCMD / BCP tools
RUN apt-get update \
 && apt-get install -y curl apt-transport-https gnupg2 \
 && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
 && echo "deb [arch=amd64,arm64,armhf] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | tee /etc/apt/sources.list.d/mssql-release.list \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 unixodbc-dev \
 # symlink to make invocation simpler - remove existing links first
 && rm -f /usr/bin/sqlcmd /usr/bin/bcp \
 && ln -s /opt/mssql-tools18/bin/sqlcmd /usr/bin/sqlcmd \
 && ln -s /opt/mssql-tools18/bin/bcp    /usr/bin/bcp \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

USER mssql
