# Micro docker
FROM ubuntu
MAINTAINER wrfly mr.wrfly@gmail.com

RUN apt-get install -y curl bsdmainutils
# Copy dao.sh adn jq(handle json)
COPY dao.sh /root
COPY jq /bin

# Env
WORKDIR /root
ENTRYPOINT ["/root/dao.sh"]
