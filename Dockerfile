# Builder Stage
FROM ruby:2.7.5-slim as builder

ENV RAILS_ENV=production \
    SECRET_KEY_BASE=dummy

WORKDIR /app

RUN apt-get update -q && \
    apt-get install -yq libpq-dev curl git libicu-dev build-essential && \
    curl https://deb.nodesource.com/setup_16.x | bash && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install --global yarn && \
    gem install bundler:2.4.9

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install -j"$(nproc)"

COPY package.json package-lock.json yarn.lock ./
COPY packages packages
RUN yarn install --frozen-lockfile

COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/ config/ bin/ db/ && \
    bundle exec rails assets:precompile

COPY ./entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

# Runner Stage
FROM ruby:2.7.5-slim as runner

ENV RAILS_ENV=production \
    SECRET_KEY_BASE=dummy \
    RAILS_LOG_TO_STDOUT=true \
    LD_PRELOAD="libjemalloc.so.2" \
    MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:5000,muzzy_decay_ms:5000,narenas:2"

WORKDIR /app

RUN apt-get update -q && \
    apt-get install -yq postgresql-client imagemagick libproj-dev proj-bin libjemalloc2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundler:2.4.9

COPY --from=builder /usr/bin/entrypoint.sh /usr/bin/entrypoint.sh
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
