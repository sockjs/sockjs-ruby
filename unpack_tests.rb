#!/usr/bin/env ruby
# encoding: utf-8

# Get list of all the tests in format for TODO.todo.

VERSION = "0.2.1"

tests = File.foreach("../protocol/sockjs-protocol-#{VERSION}.py").reduce(Hash.new) do |buffer, line|
  if line.match(/class (\w+)\(Test\)/)
    buffer[$1] = Array.new
  elsif line.match(/def (\w+)/)
    if buffer.keys.last
      buffer[buffer.keys.last] << $1
    end
  end

  buffer
end

require "yaml"

if ARGV.length == 1
  puts tests[ARGV.first].to_yaml
else
  puts tests.to_yaml
end
