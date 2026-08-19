ENV["RAILS_ENV"] ||= "test"
ENV["DB_PATH"] ||= "db/test.sqlite3"
require_relative "../config/environment"
require "rack/test"
RSpec.configure do |c|
  c.expect_with(:rspec) { |e| e.syntax = :expect }
end
