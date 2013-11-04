require 'yaml'
require 'pry'
require 'set'
require 'pathname'
require 'csv'

class YamlToCsv

  attr_reader :folder, :languages, :all_yamls, :outfile
  attr_writer :yaml_structure

  def initialize(folder='.', languages=%i(en nl), outfile='bla.csv')
    @folder = folder; @languages = languages
    @all_yamls = {}
    @outfile = outfile
    @file = csv_file
  end

  def run
    filenames = read_filenames
    filenames.each do |filename|
      write_to_csv(filename)
      write_to_csv("path", "parent", "level", *@languages)
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
    hash
  end

  def write_node(parent, path, level)
    write_to_csv(path, parent, level)
  end

  def yaml_for(language)
    all_yamls[language]
  end

  def write_leaf(value, parent, path, level)
    records = languages.inject([]) { |acc, language| acc << fetch_record_from_path(path, yaml_for(language), language) }
    write_to_csv(path, parent, level, *records)
  end

  # save path?
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
    filenames = Dir.entries(folder).select {|entry| entry =~ /.yml\z/}.inject([]) {|accum, entry| filename = entry.match(/(.+).(en|nl).yml\z/)[1]; accum += [filename] }
    filenames = Set.new(filenames).to_a
  end

  def read_yaml_structure_from_file(filename, language)
    full_path = "#{folder}/#{filename}.#{language}.yml"
    yaml = File.open(full_path).read if Pathname(full_path).exist?
    YAML.load(yaml)
  end

end

YamlToCsv.new.run
