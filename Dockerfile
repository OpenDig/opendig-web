FROM ruby:3.2.0-alpine as base

RUN apk add --update --no-cache \
  build-base \
  ca-certificates \
  glib \
  libc-dev \
  libffi-dev \
  libgcc \
  libintl \
  libstdc++ \
  libx11 \
  libxext \
  libxml2-dev \
  libxrender \
  libxslt-dev \
  nodejs \
  pcre-dev \
  ruby-dev \
  sqlite \
  sqlite-dev \
  ttf-dejavu \
  ttf-droid \
  ttf-freefont \
  ttf-liberation \
  tzdata \
  xvfb \
  zlib-dev && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  update-ca-certificates && \
  echo "Europe/London" > /etc/timezone

WORKDIR /app
RUN echo "gem: --no-ri --no-rdoc" > /etc/gemrc

COPY --from=madnight/alpine-wkhtmltopdf-builder:0.12.5-alpine3.10-606718795 \
    /bin/wkhtmltopdf /bin/wkhtmltopdf

COPY . .
# Production image: skip the development and test gem groups (rspec, rubocop,
# selenium, debug, web-console, etc.).
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

EXPOSE 3000
CMD ["bin/prod"]
