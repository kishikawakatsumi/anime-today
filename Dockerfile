FROM ruby:3

WORKDIR /app
ADD ./Gemfile* ./
ADD ./*.rb ./
RUN bundle install
EXPOSE $PORT

CMD ["bundle", "exec", "ruby", "app.rb"]
