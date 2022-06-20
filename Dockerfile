FROM ruby:3.0.3-alpine as base

RUN apk add --no-cache nodejs \
  ca-certificates \
  libxml2-dev \
  libxslt-dev \
  pcre-dev \
  libffi-dev \
  build-base \
  libc-dev \
  ruby-dev \
  zlib-dev \
  sqlite \
  sqlite-dev \
  tzdata && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  update-ca-certificates && \
  echo "Europe/London" > /etc/timezone

WORKDIR /app
RUN echo "gem: --no-ri --no-rdoc" > /etc/gemrc

COPY . .
RUN bundle install

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
