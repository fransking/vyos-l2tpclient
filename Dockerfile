FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y ca-certificates bash xl2tpd ppp net-tools iproute2 iptables nftables

RUN mkdir -p /var/run/xl2tpd
RUN touch /var/run/xl2tpd/l2tp-control

RUN mkdir /app
COPY entrypoint.sh /app

WORKDIR /app
VOLUME /lib/modules

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["client"]
