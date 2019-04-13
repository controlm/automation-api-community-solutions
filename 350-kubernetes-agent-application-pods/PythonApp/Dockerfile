#-----------------------------------------------------------------------
# Application Image for bmctwitter python code
#-----------------------------------------------------------------------

FROM python:3
MAINTAINER Joe Goldberg <joe_goldberg@bmc.com>

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY bmctwitter.py ./
COPY ct*.yaml ./

#CMD [ "python", "bmctwitter.py", "ct.yaml" ]
CMD python bmctwitter.py $BTCONF