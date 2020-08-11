FROM centos:7 as builder
MAINTAINER ybergman@bmc.com
ARG AAPI_END_POINT
ARG AAPI_USER
ARG AAPI_PASS
ARG AGENT_IMAGE_NAME

LABEL Description="This is a Control-M/Agent image that planned to run in K8s env"

# install basic packages
#-- RUN yum -y update \
#--	&& yum -y install wget \
RUN  yum -y install wget \
        && yum -y install telnet \
        && yum -y install unzip \
        && yum -y install sudo \
        && yum -y install net-tools \
        && yum -y install tcsh \
        && yum -y install openssl \
        && yum -y install openssl-devel \
        && yum -y install gcc \
        && yum -y install make \
        && yum -y install zlib-devel \
        && yum -y install libffi-devel \
		&& yum -y install compat-libstdc++-33.x86_64 \
		&& cd /usr/src \
# install python
    && wget https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tgz \
    && tar -zxf Python-3.8.5.tgz \
    && cd /usr/src/Python-3.8.5 \
#		&& wget https://www.python.org/ftp/python/2.7.15/Python-2.7.15.tgz \
#		&& tar -zxf Python-2.7.15.tgz \
#		&& cd /usr/src/Python-2.7.15 \
		&& ./configure --prefix=/usr/local --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib" --with-system-ffi --with-lto --enable-optimization \
		&& make altinstall \
# install pip
		&& cd \
		&& wget https://bootstrap.pypa.io/get-pip.py \
		&& /usr/src/Python-3.8.5/python get-pip.py \
#		&& /usr/src/Python-2.7.15/python get-pip.py \
		&& ln -sf /usr/local/bin/pip3.8 /bin/pip3.8 \
		&& pip3.8 install kubernetes \
#		&& ln -sf /usr/local/bin/pip3.8 /bin/pip2.7 \
#		&& pip2.7 install kubernetes \
# cleanup python install files
		&& cd /usr/src \
		&& rm -rf Python-3.8.5.tgz \
		&& rm -rf /usr/src/Python-3.8.5 \
#		&& rm -rf Python-2.7.15.tgz \
#		&& rm -rf /usr/src/Python-2.7.15 \
# install nodejs
		&& curl --silent --location https://rpm.nodesource.com/setup_12.x | bash - \
		&& yum -y install nodejs \
		&& node -v \
		&& npm -v \
# install aapi CLI
		&& wget --no-check-certificate $AAPI_END_POINT/ctm-cli.tgz \
		&& npm install -g ctm-cli.tgz \
		&& ctm -v \
		&& rm -rf $AAPI_END_POINT/ctm-cli.tgz \
# create controlm useruser
		&& useradd -d /home/controlm -s /bin/tcsh -m controlm \
		&&  chmod -R 755 /home/controlm \
# add controlm user and root to soduers list
		&& echo 'root ALL=(ALL) ALL' >> /etc/sudoers \
		&& echo 'controlm ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
		&& yum clean all \
		&& rm -rf /var/cache/yum
USER controlm
WORKDIR /home/controlm

# Create AAPI env
RUN ctm env add myenv $AAPI_END_POINT $AAPI_USER $AAPI_PASS \
# install java 8
		&& sudo yum -y install java-1.8.0-openjdk-headless \
        && java -version \
# install agent, setup will be done during statup
		&& ctm provision image $AGENT_IMAGE_NAME && echo installation ended successfully \
# clean
		&& sudo yum -y autoremove java-1.8.0-openjdk-headless \
		&& sudo yum clean all \
		&& sudo rm -rf /var/cache/yum


# entry point script
COPY container_agent_startup.sh  .
# script to run and monitor k8s jobs
COPY runJob.py .
# agent configuration file
COPY agent_configuration.json .

EXPOSE 7000-8000
EXPOSE 22

# create final image - reduce size
FROM builder AS builderbase

RUN sudo rm -rf /home
RUN sudo rm -rf /tmp/*

FROM scratch AS leanimage

COPY --from=builderbase / /
COPY --from=builder --chown=controlm:controlm /home /home

USER controlm
WORKDIR /home/controlm


ENTRYPOINT ["tcsh" , "-c" , "pwd ; ./container_agent_startup.sh $PERSISTENT_VOL $CTM_SERVER_NAME $CTM_AGPORT"]
