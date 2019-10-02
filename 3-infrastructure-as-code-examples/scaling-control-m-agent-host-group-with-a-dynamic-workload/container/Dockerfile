#------------------------------------
# Control-M/Agent docker container
#------------------------------------

# Base the container off of an OS Container Image that is supported for the version of the Control-M/Agent that will be deployed
FROM centos:7
# Put your email address in the maintainers line so that others in your company who might use the image know who to contact about it
LABEL maintainers="your_name@example.com"


ARG CTM_AGENT_PORT
ENV CTM_AGENT_PORT ${CTM_AGENT_PORT:-7006}

# Install required packages
RUN yum -y update \
	&& yum -y install wget unzip net-tools which java-1.8.0-openjdk sudo epel-release \
# Install nodejs
	&& curl --silent --location https://rpm.nodesource.com/setup_6.x | bash - \
	&& yum -y install nodejs \
	&& node -v \
	&& npm -v \
	&& yum clean all \
	&& rm -rf /var/cache/yum

RUN echo 'controlm ALL = NOPASSWD: /usr/bin/npm install -g ctm-cli.tgz' >> /etc/sudoers

# Add controlm user where agent will run
RUN useradd -d /home/controlm -m controlm

USER controlm

COPY run_ctmagent.sh /home/controlm

EXPOSE $CTM_AGENT_PORT

CMD ["/home/controlm/run_ctmagent.sh"]
