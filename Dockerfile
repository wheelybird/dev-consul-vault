FROM alpine

RUN apk add --update openssl bash && \
    rm -rf /var/cache/apk/*
