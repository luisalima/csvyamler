#!/usr/bin/env ruby

require 'yaml'
require 'pry'
require 'set'
require 'pathname'
require 'csv'
require 'optparse'

class YamlToCsv

  attr_reader :input_path, :languages, :all_yamls, :outfile, :fixed_row_size, :default_language, :write_default
  attr_writer :yaml_structure

  def initialize(input_path: 'in', languages: %i(en nl de), outfile: 'translations.csv', default_language: 'en', write_default: false)
    @input_path = input_path; @languages = languages
    @all_yamls = {}
    @outfile = outfile
    @file = csv_file
    @fixed_row_size = languages.size + 3
    @default_language = default_language
    @write_default = write_default
  end

  def run
    write_to_csv("$path", "parent", "level", *@languages)
    filenames = read_filenames
    filenames.each do |filename|
      puts "Processing [#{filename}]"
      write_to_csv(*(["----------"]*6))
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

  def get_record_for_pathlet(pathlets, hash)
    pathlets.each do |pathlet|
      if hash
        hash = hash[pathlet]
      else
        break
      end
    end
    hash
  end

  # fetch a record from a hash based on a path
  def fetch_record_from_path(path, hash, language)
    pathlets = [language.to_s] + path.split('.')[2..-1]
    record = get_record_for_pathlet(pathlets, hash)
    if record && !record.empty?
      record.inspect
    elsif write_default
      pathlets = [default_language.to_s] + path.split('.')[2..-1]
      "**#{get_record_for_pathlet(pathlets, yaml_for(default_language))}".inspect
    else
      empty_string
    end
  end

  def remove_language_from(path)
    "."+path.split(".")[2..-1].join('.') if path && path.length >= 1
  end

  def write_node(parent, path, level)
    write_to_csv(remove_language_from(path), parent, level)
  end

  def yaml_for(language)
    all_yamls[language.to_sym]
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
    filenames = Dir.entries(input_path).select {|entry| entry =~ /.yml\z/}.inject([]) do |accum, entry|
      if entry.match(/(.+)\.(.+).yml\z/)
        filename = entry.match(/(.+)\.(.+).yml\z/)[1]
        accum += [filename]
      end
      accum
    end
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
  opts.on('-i', '--input_path [DIR]', 'Specify input_path directory (default: in)') do |input_path|
    options[:input_path] = input_path
  end
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
  YamlToCsv.new(outfile: options.fetch(:output_file, 'translations.csv'),
                input_path: options.fetch(:input_path, 'in'),
                write_default: true).run
end
