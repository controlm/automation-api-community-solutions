# Base the container off of an OS Container Image that is supported for the version of the Control-M/Agent that will be deployed
FROM krallin/centos-tini:7
# Put your email address in the maintainers line so that others in your company who might use the image know who to contact about it
LABEL maintainers="your_name@example.com"

# Install required packages
RUN yum -y update \
    && yum -y install epel-release \
	&& yum -y install wget unzip net-tools which java-1.8.0-openjdk sudo epel-release jq gettext \
    # Install nodejs
	&& curl --silent --location https://rpm.nodesource.com/setup_6.x | bash - \
	&& yum -y install nodejs \
	&& node -v \
	&& npm -v \
	&& yum clean all \
	&& rm -rf /var/cache/yum \
    && wget https://s3-us-west-2.amazonaws.com/controlm-appdev/release/v9.19.140/ctm-cli.tgz \
    && npm install -g ctm-cli.tgz \
    # Add controlm user where agent will run
    && useradd -d /home/controlm -m controlm

USER controlm

COPY entrypoint.sh /home/controlm

ENTRYPOINT ["/usr/local/bin/tini", "--", "/home/controlm/entrypoint.sh"]