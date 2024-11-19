FROM --platform=linux/x86_64 amazonlinux:2

# Install packages
RUN yum update -y && \
    amazon-linux-extras install epel -y && \
    yum install -y cpio yum-utils tar gzip zip python3-pip shadow-utils gcc make wget which \
    xorg-x11-server-Xvfb xorg-x11-xauth zlib-devel tk-devel unzip util-linux cmake curl \
    findutils freetype-devel fribidi-devel gcc-c++ ghostscript git harfbuzz-devel lcms2-devel \
    libffi-devel libjpeg-devel libtiff-devel openssl-devel sqlite-devel pth-devel sudo 

# Install Python 3.9
RUN wget https://www.python.org/ftp/python/3.9.16/Python-3.9.16.tgz \
    && tar xzf Python-3.9.16.tgz \
    && cd Python-3.9.16 \
    && ./configure \
    && make altinstall \
    && cd .. \
    && rm -r Python-3.9.16 Python-3.9.16.tgz

WORKDIR /tmp

# Set up working directories
RUN mkdir -p /opt/app/build && \
    mkdir -p /opt/app/bin/  && \
    mkdir -p /opt/app/lib   && \
    # Download libraries we need to run in lambda
    yumdownloader -x \*i686 --archlist=x86_64 \
        clamav clamav-lib clamav-update json-c \
        pcre2 libtool-ltdl libxml2 bzip2-libs \
        xz-libs libprelude gnutls nettle libcurl \
        libnghttp2 libidn2 libssh2 openldap \
        libunistring cyrus-sasl-lib libpsl pcre openssl-libs \
        libgpg-error libcurl libnghttp2 libidn2 nss-3.79.0 && \
    RPMs=$(ls -1 *.rpm) && \
    for i in $RPMs; do rpm2cpio $i | cpio -vimd; done

# Copy over the binaries and libraries    
RUN cp -rf /tmp/usr/bin/clamscan \
        /tmp/usr/bin/freshclam \
        /opt/app/bin/ && \
    cp -rf /tmp/usr/lib64/* \
        /tmp/lib64/* \
        /opt/app/lib/ && \  
    # Fix the freshclam.conf settings
    echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
    echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf && \
    echo "ScriptedUpdates no" >> /opt/app/bin/freshclam.conf && \
    echo "DatabaseDirectory /var/lib/clamav" >> /opt/app/bin/freshclam.conf && \
    groupadd clamav && \
    useradd -g clamav -s /bin/false -c "Clam Antivirus" clamav && \
    useradd -g clamav -s /bin/false -c "Clam Antivirus" clamupdate

ENV LD_LIBRARY_PATH=/opt/app/lib
RUN ldconfig

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt
RUN python3.9 -m pip install --upgrade pip && \
    pip3 install -r requirements.txt && \
    rm -rf /root/.cache/pip

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/anti-virus.zip *.py bin lib

WORKDIR /usr/local/lib/python3.9/site-packages
RUN zip -r9 /opt/app/build/anti-virus.zip *

WORKDIR /opt/app