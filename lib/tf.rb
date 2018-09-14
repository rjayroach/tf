require "tf/version"
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'ostruct'
require 'yaml'


module Tf
  class Processor
    URL = 'https://www.terraform.io/docs/providers'.freeze

    def write
      providers.each do |provider|
        %w(d r).each do |prefix|
          FileUtils.mkdir_p("#{provider}/#{prefix}")
          Object.const_get("Tf::#{provider.capitalize}").send(prefix).each do |resource|
            res = Resource.new
            res.provider = provider
            res.prefix = prefix
            res.resource = resource
            f = File.open("#{provider}/#{prefix}/#{resource}.yml", 'w')
            f.write res.to_yml
          end
        end
      end
    end

    def providers
      %w(aws)
    end
  end

  class Base
    def doc
      Nokogiri::HTML(content)
    end

    def content
      Net::HTTP.get(URI.parse(url)).encode('utf-8', invalid: :replace, undef: :replace, replace: '_')
    end

  end

  class Provider < Base
    URL = 'https://www.terraform.io/docs/providers'.freeze
    attr_accessor :name

    def resources
    end

    def data_sources
      my_doc = doc.at_css('[id="docs-sidebar"]')
      myref = my_doc.children.children.children.children
      ref = myref.at('a:contains("Data Sources")').next.next

    end

    def url
      "#{URL}/#{name}/index.html"
    end

    def self.list
      %i(aws github kubernetes)
    end
  end

  class Resource < Base
    URL = 'https://www.terraform.io/docs/providers'.freeze
    attr_accessor :url, :provider, :prefix, :resource

    def to_yml
      self.url = "#{URL}/#{provider}/#{prefix}/#{resource}.html"
      {
        'resource' => {
          'meta' => {
            'type' => "#{provider}_#{resource}",
            'description' => ''
          },
          'variables' => arguments_hash
        }
      }.to_yaml
    end

    def arguments_hash
      arguments.each_with_object({}) do |arg, hash|
        hash[arg.name] = { 'description' => arg.description, 'required' => arg.required }
      end
    end

    def arguments
      arguments_text.children.each_with_object([]) do |argument,  ary|
        next if argument.text.eql?("\n")
        text = argument.text.split
        ary << OpenStruct.new(name: text.shift, required: text.shift(2).last.eql?('(Required)'), description: text.join(' '))
      end
    end

    def arguments_text
      a_ref = doc.at_css('[id="argument-reference"]')
      while a_ref.name != 'ul'
        a_ref = a_ref.next
      end
      a_ref
    end
  end

  class Aws
    def self.d
      %w()
    end

    def self.r
      %w(route53_zone)
    end
  end
end
