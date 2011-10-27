# encoding: utf-8

# Use local clones if possible.
# If you want to use your local copy, just symlink it to vendor.
extend Module.new {
  def gem(name, options = Hash.new)
    local_path = File.expand_path("../vendor/#{name}", __FILE__)
    if File.exist?(local_path)
      super name, options.merge(:path => local_path).delete_if { |key, _| [:git, :branch].include?(key) }
    else
      super name, options
    end
  end
}

source :rubygems

gem "eventmachine"
