FROM alpine:edge

EXPOSE 8888

RUN apk add --no-cache tinyproxy openvpn curl

COPY app /app

RUN chmod u+x /app/run.sh

CMD ["/app/run.sh"]
