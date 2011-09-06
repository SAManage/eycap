require 'erb'

Capistrano::Configuration.instance(:must_exist).load do

  namespace :mongodb do
    task :backup_name, :roles => :db, :only => { :primary => true } do
      now = Time.now
      run "mkdir -p #{shared_path}/db_backups"
      backup_time = [now.year,now.month,now.day,now.hour,now.min,now.sec].join('-')
      set :backup_file, "#{shared_path}/db_backups/#{environment_database}-snapshot-#{backup_time}.sql"
    end

    desc "Clone production database to staging database."
    task :clone_prod_to_staging, :roles => :db, :only => { :primary => true } do

      # This task currently runs only on traditional EY offerings.
      # You need to have both a production and staging environment defined in
      # your deploy.rb file.

      backup_name unless exists?(:backup_file)
      run("cat #{shared_path}/config/database.yml") { |channel, stream, data| @environment_info = YAML.load(data)[rails_env] }
      dump

      if ['mysql', 'mysql2'].include? @environment_info['adapter']
        run "gunzip < #{backup_file}.gz | mysql -u #{dbuser} -p -h #{staging_dbhost} #{staging_database}" do |ch, stream, out|
           ch.send_data "#{dbpass}\n" if out=~ /^Enter password:/
        end
      else
        run "gunzip < #{backup_file}.gz | psql -W -U #{dbuser} -h #{staging_dbhost} #{staging_database}" do |ch, stream, out|
           ch.send_data "#{dbpass}\n" if out=~ /^Password/
        end
      end
      run "rm -f #{backup_file}.gz"         
    end

    desc "Backup your MySQL database to shared_path/db_backups."
    task :dump, :roles => :db, :only => {:primary => true} do
      backup_name unless exists?(:backup_file)
      on_rollback { run "rm -f #{backup_file}" }
      run("cat #{shared_path}/config/database.yml") { |channel, stream, data| @environment_info = YAML.load(data)[rails_env] }
      
      if ['mysql', 'mysql2'].include? @environment_info['adapter']
        dbhost = @environment_info['host']
        if rails_env == "production"
          dbhost = environment_dbhost.sub('-master', '') + '-replica' if dbhost != 'localhost' # added for Solo offering, which uses localhost
        end
        run "mysqldump --add-drop-table -u #{dbuser} -h #{dbhost} -p #{environment_database} | gzip -c > #{backup_file}.gz" do |ch, stream, out |
           ch.send_data "#{dbpass}\n" if out=~ /^Enter password:/
        end
      else
        run "pg_dump -W -c -U #{dbuser} -h #{environment_dbhost} #{environment_database} | gzip -c > #{backup_file}.gz" do |ch, stream, out |
           ch.send_data "#{dbpass}\n" if out=~ /^Password:/
        end
      end
    end

    desc "Sync your production database to your local workstation."
    task :clone_to_local, :roles => :db, :only => {:primary => true} do
      backup_name unless exists?(:backup_file)
      dump
      get "#{backup_file}.gz", "/tmp/#{application}.sql.gz"
      development_info = YAML.load(ERB.new(File.read('config/database.yml')).result)['development']

      if ['mysql', 'mysql2'].include? development_info['adapter']
        run_str = "gunzip < /tmp/#{application}.sql.gz | mysql -u #{development_info['username']} --password='#{development_info['password']}' -h #{development_info['host']} #{development_info['database']}"
      else
        run_str  = ""
        run_str += "PGPASSWORD=#{development_info['password']} " if development_info['password']
        run_str += "gunzip < /tmp/#{application}.sql.gz | psql -U #{development_info['username']} "
        run_str += "-h #{development_info['host']} "             if development_info['host']
        run_str += development_info['database']
      end
      %x!#{run_str}!
      run "rm -f #{backup_file}.gz"
    end
  end

end
