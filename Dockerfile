#Use debian:stable-slim as a builder and then copy everything.
FROM debian:stable-slim as builder

#Set mosquitto and plugin versions.
#Change them for your needs.
ENV MOSQUITTO_VERSION=1.6.10
ENV PLUGIN_VERSION=0.6.1
ENV GO_VERSION=1.13.8

WORKDIR /app

#Get mosquitto build dependencies.
RUN apt-get update && apt-get install -y libwebsockets8 libwebsockets-dev libc-ares2 libc-ares-dev openssl uuid uuid-dev wget build-essential git
RUN mkdir -p mosquitto/auth mosquitto/conf.d

RUN wget http://mosquitto.org/files/source/mosquitto-${MOSQUITTO_VERSION}.tar.gz
RUN tar xzvf mosquitto-${MOSQUITTO_VERSION}.tar.gz && rm mosquitto-${MOSQUITTO_VERSION}.tar.gz 

#Build mosquitto.
RUN cd mosquitto-${MOSQUITTO_VERSION} && make WITH_WEBSOCKETS=yes && make install && cd ..

#Get Go.
RUN wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
RUN export PATH=$PATH:/usr/local/go/bin && go version && rm go${GO_VERSION}.linux-amd64.tar.gz

#Get the plugin.
RUN wget https://github.com/iegomez/mosquitto-go-auth/archive/${PLUGIN_VERSION}.tar.gz \
    && ls -l \
    && tar xvf *.tar.gz --strip-components=1 \
    && rm -Rf go*.tar.gz \
    && ls -l

#Build the plugin.
RUN export PATH=$PATH:/usr/local/go/bin && export CGO_CFLAGS="-I/usr/local/include -fPIC" && export CGO_LDFLAGS="-shared" &&  make

#Get the oauth plugin
COPY src/* oauth_plugin/ 
RUN export PATH=$PATH:/usr/local/go/bin && go build -buildmode=plugin -o mosquitto-go-auth-oauth2.so oauth_plugin/main.go

#Start from a new image.
FROM debian:stable-slim

#Get mosquitto dependencies.
RUN apt-get update && apt-get install -y libwebsockets8 libc-ares2 openssl uuid ca-certificates
RUN update-ca-certificates

#Setup mosquitto env.
RUN mkdir -p /var/lib/mosquitto /var/log/mosquitto 
RUN groupadd mosquitto \
    && useradd -s /sbin/nologin mosquitto -g mosquitto -d /var/lib/mosquitto \
    && chown -R mosquitto:mosquitto /var/log/mosquitto/ \
    && chown -R mosquitto:mosquitto /var/lib/mosquitto/

#Copy confs, plugin so and mosquitto binary.
COPY --from=builder /app/mosquitto/ /mosquitto/
COPY --from=builder /app/go-auth.so /mosquitto/go-auth.so
COPY --from=builder /usr/local/sbin/mosquitto /usr/sbin/mosquitto
COPY --from=builder /app/mosquitto-go-auth-oauth2.so /mosquitto/mosquitto-go-auth-oauth2.so
COPY --from=builder /app/pw /mosquitto/pw

#Uncomment to copy your custom confs (change accordingly) directly when building the image.
#Leave commented if you want to mount a volume for these (see docker-compose.yml).

# COPY example_conf/mosquitto.conf /etc/mosquitto/mosquitto.conf
# COPY example_conf/conf.d/go-auth.conf /etc/mosquitto/conf.d/go-auth.conf
# COPY example_conf/auth/acls /etc/mosquitto/auth/acls
# COPY example_conf/auth/passwords /etc/mosquitto/auth/passwords

#Expose tcp and websocket ports as defined at mosquitto.conf (change accordingly).
EXPOSE 1883 1884

RUN apt-get install -y procps nano
COPY start.sh /start.sh

# ENTRYPOINT ["sh", "-c", "/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf" ]
 ENTRYPOINT ["sh", "-c", "/start.sh" ]