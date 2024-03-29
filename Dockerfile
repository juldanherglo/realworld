# This is a multi-stage Dockerfile and requires >= Docker 17.05
# https://docs.docker.com/engine/userguide/eng-image/multistage-build/
FROM gobuffalo/buffalo:v0.18.8 as builder

RUN mkdir -p "$GOPATH/src/gobuff_realworld_example_app"
WORKDIR $GOPATH/src/gobuff_realworld_example_app

COPY . .
ENV GO111MODULES=on
RUN go get ./... && buffalo build --static -o /bin/app

FROM alpine:3.16.2
RUN apk add --no-cache bash=5.1.16-r2 ca-certificates=20220614-r0

WORKDIR /bin/

COPY --from=builder /bin/app .

# Uncomment to run the binary in "production" mode:
# ENV GO_ENV=production

# Bind the app to 0.0.0.0 so it can be seen from outside the container
ENV ADDR=0.0.0.0

EXPOSE 3000

## Add the wait script to the image
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /wait
RUN chmod +x /wait

# Run the migrations before running the binary:
CMD ["bash", "-c", "/wait; /bin/app migrate; /bin/app"]
