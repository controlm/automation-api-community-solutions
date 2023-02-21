# /bin/bash

#set -vx

#echo "$*" | tee -a args_passed.log

#$(which python) /home/saasaapi/extalerts/extalert.py "$*" | tee -a extalert.log
$(which python) /home/saasaapi/extalerts/extalert.py "$*"

