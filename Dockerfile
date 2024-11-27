FROM --platform=linux/x86_64 public.ecr.aws/lambda/python:3.9

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
# update security
RUN : \
    && yum -y update --security \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && :

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
# Install required packages
RUN : \
    && yum update -y \
    && yum install -y \
        cpio \
        python3 \
        python3-pip \
        yum-utils \
        zip \
        unzip \
        less \
        libtool-ltdl \
        binutils \
    # && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && pip3 install -r /opt/app/requirements.txt \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && :

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN yumdownloader -x \*i686 --archlist=x86_64 \
  clamav \
  clamav-lib \
  clamav-scanner-systemd \
  clamav-update \
  elfutils-libs \
  json-c \
  lz4 \
  pcre \
  systemd-libs \
  libprelude \
  gnutls \
  libtasn1 \
  lib64nettle \
  nettle \
  libtool-ltdl \
  bzip2-libs \
  libxml2 \
  xz-libs \
  xz-devel

RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio clamd-0*.rpm | cpio -idmv
RUN rpm2cpio elfutils-libs*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio lz4*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio systemd-libs*.rpm | cpio -idmv
RUN rpm2cpio gnutls* | cpio -idmv
RUN rpm2cpio nettle* | cpio -idmv
RUN rpm2cpio libtasn1* | cpio -idmv
RUN rpm2cpio libtool-ltdl* | cpio -idmv
RUN rpm2cpio bzip2-libs*.rpm | cpio -idmv
RUN rpm2cpio libxml2* | cpio -idmv
RUN rpm2cpio xz-libs* | cpio -idmv
RUN rpm2cpio xz-devel* | cpio -idmv
RUN rpm2cpio lib* | cpio -idmv
RUN rpm2cpio *.rpm | cpio -idmv

# Copy over the binaries and libraries
RUN cp -r /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /var/lang/lib/python3.9/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app