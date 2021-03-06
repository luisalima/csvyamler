#!/usr/bin/env ruby

require 'yaml'
require 'pry'
require 'set'
require 'pathname'
require 'csv'
require 'optparse'

class CsvToYaml

  attr_reader :languages, :outpath

  def initialize(infile: 'translations.csv', outpath: 'out')
    @infile = infile; @yaml_files = {}; @outpath = outpath
    Dir.mkdir(@outpath) unless File.exists? File.expand_path(outpath)
  end

  def run
    read_all
  end

  def languages
    @languages ||= %w(en nl de)
  end

  def yaml_file_for(filename, language)
    @yaml_files[language] ||= {}
    @yaml_files[language][filename] ||= File.open("#{outpath}/#{filename}.#{language.to_s}.yml", "w")
  end

  def close_language_files
    languages.each do |language|
      @yaml_files[language].each { |k, file| file.close }
    end
  end

  def get_index_for(language)
    indexes = {en: 0, nl: 1, de: 2}
    indexes[language.to_sym]
  end

  def read_all
    filename = ''
    CSV.foreach(@infile, 'r') do |row|
      path = row[0]; parent=row[1]; level=row[2].to_i; values = row[3..-1]
      next if path && (path[0] == '$' || path[0] == '-')

      if(new_filename(path))
        filename = new_filename(path)
        puts "Creating [#{filename}]..."
      else
        languages.each do |language|
          parent = language if languages.include? parent
          value = values[get_index_for(language)] if values
          s = create_yaml_for_path(".#{language.to_s}#{path}", parent, level, value)
          yaml_file_for(filename, language).write(s)
        end
      end
    end
    close_language_files
  end

  def new_filename(path)
    if path && path[0] != '.' && path[0] !=  '$'
      path
    else
      nil
    end
  end

  def create_yaml_for_path(path, parent, level, value)
    return unless path && parent && level != 0
    s = " "*((level-1)*2) + "#{parent}:"
    s += " #{value}" unless value == nil
    "#{s}\n"
  end

end

options = {}
opt = OptionParser.new do |opts|
  opts.banner = 'Usage: csv_to_yaml.rb [options]'
  opts.on('-i', '--input [FILE]', 'Specify input file (default: translations.csv)') do |input_file|
    options[:input_file] = input_file
  end
  opts.on('-o', '--output [FOLDER]', 'Specify output folder path (default: ./out). Will be created if unexistent.') do |output_folder|
    options[:output_folder] = output_folder
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
  CsvToYaml.new(infile: options.fetch(:input_file, 'translations.csv'),
                outpath: options.fetch(:output_folder, './out')).run
end
