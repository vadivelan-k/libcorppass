# libcorppass
[![Build Status](https://travis-ci.org/idagds/libcorppass.svg?branch=master)](https://travis-ci.org/idagds/libcorppass)

A wrapper around [libsaml](https://github.com/digidentity/libsaml) to perform authentication with CorpPass for Ruby applications.

API Documentation (TODO)

# Install

1. Add this to your `Gemfile`:

        gem 'libcorppass', git: 'https://github.com/idagds/libcorppass.git'

2. Run `bundle`

# Usage
language: ruby
rvm:
  - 2.2
before_script:
  - "bundle exec rake db:migrate RAILS_ENV=test"
script: bundle exec rake test
install: bundle install --jobs=3 --retry=3
TODO: Initialisation, integration, examples 

# License

LGPL. See `LICENSE` for full text.  
&copy; 2016 Government Digital Services, Infocomm Development Authority of Singapore
