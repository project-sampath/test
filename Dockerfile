
# -----------------------------------------
# (1) jboss-eap-7.1.x.zip (RedHat JBoss EAP 7.1.x	Application Platform - zip file downloaded from https://developers.redhat.com/products/eap/download/)
#
# HOW TO BUILD THIS IMAGE
# -----------------------------------------
#      $ docker build -t pega-jboss:1 .

FROM jboss/base-jdk:8
ARG JBOSS_VERSION=7.1

ARG HOME=/opt/jboss
ARG JBOSS_MGMT_NATIVE_PORT=9999
ARG JBOSS_MGMT_HTTP_PORT=9990
ARG JBOSS_HTTP_PORT=8080
ARG ADMIN_PASSWORD=MRPTS
ARG ADMIN_DATASOURCE=true
ENV JBOSS_HOME /opt/jboss/jboss-eap-7.1
#ENV HTTP_PROXY "http://sps1:spssvl28@10.201.112.111:3128"
#ENV HTTPS_PROXY "http://sps1:spssvl28@10.201.112.111:3128"


RUN mkdir -p /opt/jboss
COPY media/jboss-eap-$JBOSS_VERSION.zip /opt/jboss
#WORKDIR ${HOME}
RUN cd $HOME \
    && unzip jboss-eap-$JBOSS_VERSION.zip \
    && rm -rf jboss-eap-$JBOSS_VERSION.zip
# create JBoss console user
RUN $JBOSS_HOME/bin/add-user.sh admin $ADMIN_PASSWORD --silent
USER root
# Setup Pega requirements
# --------------------------------
RUN mkdir -p /pega/pegatemp && \
        mkdir -p /pega/pegalogs && \
        mkdir -p /pega/pegaconfig && \
        mkdir -p /pega/PegaSearchIndex && \
    chmod a+xr /pega
##Copy pega prconfig.xml, prbootstrap.properties and prlog4j2.xml into pegaconfig
ADD pega/pega-config/* /pega/pegaconfig/


# Expose JBoss ports
EXPOSE $JBOSS_HTTP_PORT $JBOSS_MGMT_NATIVE_PORT $JBOSS_MGMT_HTTP_PORT
# Define default command to start bash.
ADD startjboss.sh /startjboss.sh
RUN chmod +x /startjboss.sh
##Removing default standalone configuration files and Adding Pega configurations (standalone full and config file)
RUN rm -rf $JBOSS_HOME/standalone/configuration/standalone-full.xml \
    && rm -rf $JBOSS_HOME/bin/standalone.conf
##Adding standalone-full.xml and standalone.conf
ADD pega/jboss-config/standalone-full.xml "$JBOSS_HOME/standalone/configuration/"
ADD pega/jboss-config/standalone.conf "$JBOSS_HOME/bin/"

##Adding sqljdbc driver
ADD pega/driver/sqljdbc42.jar "$JBOSS_HOME/modules/system/layers/base/com/microsoft/main/"
ADD pega/driver/module.xml "$JBOSS_HOME/modules/system/layers/base/com/microsoft/main/"
# go to $JBOSS_HOME as user 'jboss'
RUN chown -R root:root $JBOSS_HOME && chown -R root:root /pega
WORKDIR $JBOSS_HOME
ENTRYPOINT ["/startjboss.sh"]
#Deploy EAR and WAR
ADD pega/deploy/* "$JBOSS_HOME/standalone/deployments/"
USER root
CMD /bin/bash/
