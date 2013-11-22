#!/usr/bin/env ruby

require 'yaml'
require 'pry'
require 'set'
require 'pathname'
require 'csv'
require 'optparse'

class YamlToCsv

  attr_reader :input_path, :languages, :all_yamls, :outfile, :fixed_row_size
  attr_writer :yaml_structure

  def initialize(input_path: 'in', languages: %i(en nl de), outfile: 'translations.csv')
    @input_path = input_path; @languages = languages
    @all_yamls = {}
    @outfile = outfile
    @file = csv_file
    @fixed_row_size = languages.size + 3
  end

  def run
    write_to_csv("$path", "parent", "level", *@languages)
    filenames = read_filenames
    filenames.each do |filename|
      puts "Processing [#{filename}]"
      write_to_csv(filename)
      languages.each { |language| all_yamls[language] = read_yaml_structure_from_file(filename, language)}
      depth_first_traversal(all_yamls[:en])
    end
    close_csv_file
  end

  protected

  def csv_file
    @file ||= CSV.open(@outfile, 'wb')
    @file
  end

  def close_csv_file
    @file.close
  end

  def write_to_csv(*row)
    row += [nil]*(fixed_row_size-row.size)
    csv_file << row
  end

  def empty_string
    "\"\""
  end

  # fetch a record from a hash based on a path
  def fetch_record_from_path(path, hash, language)
    pathlets = path.split('.')
    pathlets = [language.to_s] + pathlets[2..-1]
    pathlets.each do |pathlet|
      if hash
        hash = hash[pathlet]
      else
        break
      end
    end
    hash ? hash.inspect : empty_string
  end

  def remove_language_from(path)
    "."+path.split(".")[2..-1].join('.') if path && path.length >= 1
  end

  def write_node(parent, path, level)
    write_to_csv(remove_language_from(path), parent, level)
  end

  def yaml_for(language)
    all_yamls[language]
  end

  def write_leaf(value, parent, path, level)
    records = languages.inject([]) { |acc, language| acc << fetch_record_from_path(path, yaml_for(language), language) }
    write_to_csv(remove_language_from(path), parent, level, *records)
  end

  def depth_first_traversal(h, parent=nil, path="", level=0)
    if h.kind_of? String
      write_leaf(h, parent, path, level)
    elsif h.kind_of?(Hash)
      write_node(parent, path, level)
      h.each do |parent, new_h|
        depth_first_traversal(new_h, parent, "#{path}.#{parent}", level+1)
      end
    end
  end

  def read_filenames
    filenames = Dir.entries(input_path).select {|entry| entry =~ /.yml\z/}.inject([]) {|accum, entry| filename = entry.match(/(.+)\.(.+).yml\z/)[1]; accum += [filename] }
    filenames = Set.new(filenames).to_a
  end

  def read_yaml_structure_from_file(filename, language)
    full_path = "#{input_path}/#{filename}.#{language}.yml"
    if Pathname(full_path).exist?
      yaml = File.open(full_path).read
      YAML.load(yaml)
    end
  end

end

options = {}
opt = OptionParser.new do |opts|
  opts.banner = 'Usage: yaml_to_csv.rb [options]'
  opts.on('-o', '--output [FILE]', 'Specify output file (default: translations.csv)') do |output_file|
    options[:output_file] = output_file
  end
  opts.on('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
end

opt.parse!

if options == {}
  puts opt
else
  YamlToCsv.new(outfile: options.fetch(:output_file, 'translations.csv')).run
end
