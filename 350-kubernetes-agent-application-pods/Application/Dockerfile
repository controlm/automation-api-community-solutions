#-----------------------------------------------------------------------
# Simple container to mimic an application component
#-----------------------------------------------------------------------

FROM alpine:latest
MAINTAINER Joe Goldberg <joe_goldberg@bmc.com>
# copy "application" script to container
COPY run_app.sh /run_app.sh
RUN chmod +x /run_app.sh

ENTRYPOINT ["./run_app.sh"]
