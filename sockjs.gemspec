#!/usr/bin/env gem build
# encoding: utf-8

require "base64"

require File.expand_path("../lib/sockjs/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "sockjs"
  s.version = SockJS::VERSION
  s.authors = ["Jakub Stastny"]
  s.homepage = "https://github.com/sockjs/sockjs-ruby"
  s.summary = "Ruby server for SockJS"
  s.description = <<-DESC
    SockJS is WebSocket emulation library. It means that you use the WebSocket API, only instead of WebSocket class you instantiate SockJS class.
  DESC
  s.email = "jakub@rabbitmq.com"

  # Ruby version
  s.required_ruby_version = ::Gem::Requirement.new("~> 1.9")

  # Dependencies
  s.add_dependency "rack"
  s.add_dependency "thin"

  # Files
  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.extra_rdoc_files = ["README.textile"]

  # RubyForge
  s.rubyforge_project = "sockjs"
end
