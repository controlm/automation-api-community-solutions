#!/bin/bash

#--------------------------------------------------
#  Control-M/Agent Vagrant Provision
#--------------------------------------------------

# if .ctm_env file already exist use that, otherwise create one
if [ -f ~/.ctm_env ]; then
   . ~/.ctm_env
else
	export CTM_HOST="$1"
	export CTM_USER="$2"
	export CTM_PASSWORD="$3"
	export CTM_SERVER="$4"
	export CTM_AGENT_HOST="$5"
	export CTM_AGENT_PORT="$6"

	#create .ctm_env for scripts and easy source of working environment
	echo "export CTM_HOST=\"$1\"" > .ctm_env
	echo "export CTM_USER=\"$2\"" >> .ctm_env
	echo "export CTM_PASSWORD=\"$3\"" >> .ctm_env
	echo "export CTM_SERVER=\"$4\"" >> .ctm_env
	echo "export CTM_AGENT_HOST=\"$5\"" >> .ctm_env
	echo "export CTM_AGENT_PORT=\"$6\"" >> .ctm_env
fi

# add controlm endpoint
ctm env add endpoint https://$CTM_HOST:8443/automation-api $CTM_USER $CTM_PASSWORD \
	&& ctm env set endpoint 

# provision controlm agent image
ctm provision image Agent_18.Linux

# enable controlm agent utilities
echo "source .bash_profile" >> .bashrc

# register agent
/vagrant/register_agent.sh
