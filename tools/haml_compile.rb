#!/usr/bin/env ruby
# haml_compile.rb — Compile HAML to HTML using Haml 6 Template API
require 'haml'

input_file = ARGV[0]
output_file = ARGV[1]

unless input_file && output_file
  $stderr.puts "Usage: ruby haml_compile.rb <input.haml> <output.html>"
  exit 1
end

haml_content = File.read(input_file, encoding: 'UTF-8')
template = Haml::Template.new { haml_content }
html_output = template.render

File.write(output_file, html_output, encoding: 'UTF-8')
puts "Compiled: #{input_file} -> #{output_file}"
