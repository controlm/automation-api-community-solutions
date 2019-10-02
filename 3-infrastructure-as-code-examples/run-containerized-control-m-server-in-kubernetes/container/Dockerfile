#------------------------------------
# Control-M/Agent docker container
#------------------------------------

# Base the container off of an OS Container Image that is supported for the version of the Control-M/Agent that will be deployed
FROM centos:7
# Put your email address in the maintainers line so that others in your company who might use the image know who to contact about it
LABEL maintainers="your_name@example.com"


# Install required packages
RUN yum -y update \
	&& yum -y install tcsh wget unzip net-tools which java-1.8.0-openjdk sudo epel-release libaio \
# Install nodejs
	&& curl --silent --location https://rpm.nodesource.com/setup_6.x | bash - \
	&& yum -y install nodejs \
	&& node -v \
	&& npm -v \
	&& yum clean all \
	&& rm -rf /var/cache/yum

RUN echo 'controlm ALL = NOPASSWD: /usr/bin/npm install -g ctm-cli.tgz' >> /etc/sudoers

# Add controlm user where agent will run
RUN useradd -s /bin/tcsh -d /home/controlm -m controlm

USER controlm

COPY run_ctmserver.sh /home/controlm

CMD ["/home/controlm/run_ctmserver.sh"]
