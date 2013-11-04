require 'yaml'
require 'pry'
require 'set'
require 'pathname'
require 'csv'

class CsvToYaml

  attr_reader :languages, :outpath

  def initialize(folder='.', infile='bla.csv', outpath='out')
    @folder = folder; @infile = infile; @yaml_files = {}; @outpath = outpath
    Dir.mkdir(@outpath) unless File.exists? File.expand_path(outpath)
  end

  def run
    read_all
  end

  def languages
    @languages ||= %w(en nl)
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
    indexes = {en: 0, nl: 1}
    indexes[language.to_sym]
  end

  def read_all
    filename = 'tmp'
    CSV.foreach(@infile, 'r') do |row|
      path = row[0]; parent=row[1]; level=row[2].to_i; values = row[3..-1]
      if(new_filename(path))
        filename = new_filename(path)
        p "Creating [#{filename}]..."
      else
        languages.each do |language|
          parent = language if parent == 'en'
          value = values[get_index_for(language)] if values
          s = create_yaml_for_path(".#{language.to_s}#{path}", parent, level, value)
          yaml_file_for(filename, language).write(s)
        end
      end
    end
    close_language_files
  end

  def new_filename(path)
    if path && path[0] != '.' && path[0] !=  '#'
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

class YamlToCsv

  attr_reader :input_path, :languages, :all_yamls, :outfile
  attr_writer :yaml_structure

  def initialize(input_path='in', languages=%i(en nl), outfile='bla.csv')
    @input_path = input_path; @languages = languages
    @all_yamls = {}
    @outfile = outfile
    @file = csv_file
  end

  def run
    write_to_csv("#path", "parent", "level", *@languages)
    filenames = read_filenames
    filenames.each do |filename|
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
    csv_file << (Array.new) << row
  end

  # fetch a record from a hash based on a path
  def fetch_record_from_path(path, hash, language)
    pathlets = path.split('.')
    pathlets = [language.to_s] + pathlets[2..-1]
    pathlets.each { |pathlet| hash = hash[pathlet] }
    "\"#{hash}\""
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
    filenames = Dir.entries(input_path).select {|entry| entry =~ /.yml\z/}.inject([]) {|accum, entry| filename = entry.match(/(.+).(en|nl).yml\z/)[1]; accum += [filename] }
    filenames = Set.new(filenames).to_a
  end

  def read_yaml_structure_from_file(filename, language)
    full_path = "#{input_path}/#{filename}.#{language}.yml"
    yaml = File.open(full_path).read if Pathname(full_path).exist?
    YAML.load(yaml)
  end

end

#YamlToCsv.new.run
CsvToYaml.new.run
