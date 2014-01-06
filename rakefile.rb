def system!(cmdline)
  puts "[#{Time.now}] #{cmdline}"
  rc = system(cmdline)
  "failed with exit code #{$?.exitstatus}" if (rc.nil? || ! rc || $?.exitstatus != 0)
end

SCRIPT_LOCATION="."

namespace :translations do

  task :get_csv do
  end

  task :convert_from_csv do
    system! "rm -r out/"
    system! "source ./set_env.sh && #{SCRIPT_LOCATION}/csv_to_yaml.rb -i $CSV_PATH -o $LOCALES_PATH"
  end

  task :convert_from_yml do
    system! "source ./set_env.sh && #{SCRIPT_LOCATION}/yaml_to_csv.rb -i $LOCALES_PATH -o $CSV_PATH"
  end
end
