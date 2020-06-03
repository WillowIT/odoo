FROM ubuntu:20.04
ENV LANG C.UTF-8

# Create odoo user
USER root
RUN useradd -ms /bin/bash odoo
COPY ./ /home/odoo/odoo-13/odoo/
COPY ./container/.ssh/* /home/odoo/.ssh/
COPY ./container/odoo-server.conf /home/odoo/
COPY ./container/start_odoo.sh /home/odoo/
RUN chown -R odoo:odoo /home/odoo/*

# Install dependent software
ENV TZ=Australia/Melbourne
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y upgrade
RUN apt-get install software-properties-common -y && add-apt-repository ppa:deadsnakes/ppa -y && apt-get update
RUN apt-get update && apt-get install -y python3.6 python-dev python3.6-dev build-essential libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev ca-certificates curl systemd nginx
RUN curl https://bootstrap.pypa.io/get-pip.py | python3.6
RUN apt-get update && apt-get -y install sudo rsyslog
RUN echo "odoo ALL=NOPASSWD: ALL" >> /etc/sudoers
RUN echo "Set disable_coredump false" >> /etc/sudo.conf

# Setup SSH access for debugging and maintenance
RUN apt-get update && apt-get -y install openssh-server
RUN chmod 700 /home/odoo/.ssh && chmod 600 /home/odoo/.ssh/authorized_keys && chown -R odoo:odoo /home/odoo/.ssh/
COPY ./container/openssh-server/ /etc/ssh/
RUN echo "NOTE: This is containerised Odoo Instance.\n      Changes made outside of \"/persistent_storage\" will not be saved.\n" > /etc/motd

# Install WKHTML
RUN set -x; \
    curl -o wkhtmltox.deb -sSL https://downloads.wkhtmltopdf.org/0.12/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Create directory to mount persistent data
RUN mkdir /persistent_storage

# Install Postgresql
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" > /etc/apt/sources.list.d/PostgreSQL.list
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get update && apt-get install -y software-properties-common postgresql-10 postgresql-client-10 postgresql-contrib-10

RUN mkdir /persistent_storage/postgresql_data
RUN chown postgres:postgres /persistent_storage/postgresql_data
RUN rm /etc/postgresql/10/main/postgresql.conf
COPY ./container/postgresql/ /etc/postgresql/10/main/

# Install start script requirements
RUN apt-get update && apt-get install -y lsof net-tools

# Setup NGINX
RUN rm /etc/nginx/sites-enabled/default
COPY ./container/nginx/ /etc/nginx/

# Install Odoo python dependencies
RUN pip3.6 install -r /home/odoo/odoo-13/odoo/requirements.txt

# Define volume to persist DB and Odoo filestore
VOLUME ["/persistent_storage"]

# Expose Odoo services
EXPOSE 2223 8088

USER odoo
CMD bash /home/odoo/start_odoo.sh
