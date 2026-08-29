FROM ruby:3.3-alpine AS gems

RUN apk add --no-cache build-base

WORKDIR /app

COPY Gemfile ./
RUN bundle config set without 'development test' && bundle install

FROM ruby:3.3-alpine

RUN apk add --no-cache imagemagick librsvg rsvg-convert font-dejavu fontconfig tzdata libstdc++

WORKDIR /app

COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY . .

ENV RACK_ENV=production \
    PORT=4567 \
    TZ=UTC

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-p", "4567", "config.ru"]
