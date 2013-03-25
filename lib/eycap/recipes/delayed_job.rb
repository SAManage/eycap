Capistrano::Configuration.instance(:must_exist).load do
  namespace :dj do
    desc <<-DESC
    Start the Delayed Job queue along with any in the same monit_group.
    DESC
    task :start, :roles => [:app], :only => {:dj => true} do
      sudo "/usr/bin/monit start all -g dj_#{monit_group}"
    end

    desc <<-DESC
    Restart the Delayed Job queue along with any in the same monit_group.
    DESC
    task :restart, :roles => [:app], :only => {:dj => true} do
      sudo "/usr/bin/monit restart all -g dj_#{monit_group}"
    end

    desc <<-DESC
    Stop all monit group members, of which delayed job can be a part of.
    DESC
    task :stop, :roles => [:app], :only => {:dj => true} do
      sudo "/usr/bin/monit stop all -g dj_#{monit_group}"
    end
    
  end #namespace
end #Capistrano::Configuration
