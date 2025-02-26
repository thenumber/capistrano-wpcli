namespace :load do

  task :defaults do

    # The url under which the wordpress installation is
    # available on the remote server
    set :wpcli_remote_url, "http://example.com"
    # array of domains for use on multisites
    set :wpcli_remote_urls, []

    # The url under which the wordpress installation is
    # available on the local server
    set :wpcli_local_url, "http://example.dev"
    # array of local domains for use on multisite
    set :wpcli_local_urls, []


    # A local temp dir which is read and writeable
    set :local_tmp_dir, "/tmp"

    # Use current time for annotating the backup file
    set :current_time, -> { Time.now.strftime("%Y%m%d%H%M") }

    # Boolean to determine wether the database should be backed up or not
    set :wpcli_backup_db, false

    # Set the location of the db backup files. This is relative to the local project root path.
    set :wpcli_local_db_backup_dir, "config/backup"

    # Temporary db dumps path
    set :wpcli_remote_db_file, -> {"#{fetch(:tmp_dir)}/wpcli_database.sql.gz"}
    set :wpcli_local_db_file, -> {"#{fetch(:local_tmp_dir)}/wpcli_database.sql.gz"}

    # Backup file filename
    set :wpcli_local_db_backup_filename, -> {"db_#{fetch(:stage)}_#{fetch(:current_time)}.sql.gz"}

  end

end

namespace :wpcli do

  namespace :db do

    desc "Pull the remote data"
    task :pull do
      on roles(:web) do
        within release_path do
          execute :wp, :db, :export, "- |", :gzip, ">", fetch(:wpcli_remote_db_file)
          download! fetch(:wpcli_remote_db_file), fetch(:wpcli_local_db_file)
          execute :rm, fetch(:wpcli_remote_db_file)
        end
      end

      unless roles(:dev).empty?
        on roles(:dev) do
          within fetch(:dev_path) do
            local_tmp_file = fetch(:wpcli_local_db_file).gsub(/\.gz$/, "")
            upload! fetch(:wpcli_local_db_file), fetch(:wpcli_local_db_file)
            execute :gunzip, "-c", fetch(:wpcli_local_db_file), ">", local_tmp_file
            execute :wp, :db, :import, local_tmp_file
            execute :rm, fetch(:wpcli_local_db_file), local_tmp_file
            if fetch(:wpcli_remote_urls).length > 0 || fetch(:wpcli_local_urls).length > 0
              if fetch(:wpcli_remote_urls).length == fetch(:wpcli_local_urls).length
                fetch(:wpcli_remote_urls).each_with_index do |url, i|
                  execute :wp, "search-replace", url, fetch(:wpcli_local_urls)[i], fetch(:wpcli_args) || "--skip-columns=guid", "--all-tables-with-prefix=wp"
                  execute :wp, "search-replace", "https://#{fetch(:wpcli_local_urls)[i]}", "http://#{fetch(:wpcli_local_urls)[i]}", fetch(:wpcli_args) || "--skip-columns=guid", "--all-tables-with-prefix=wp"
                end
              else
                error = CommandError.new("remote_urls array and local_urls array not the same length")
                raise error
              end
            else
              execute :wp, "search-replace", fetch(:wpcli_remote_url), fetch(:wpcli_local_url), fetch(:wpcli_args) || "--skip-columns=guid", "--url=" + fetch(:wpcli_remote_url)
            end
          end
        end
        run_locally do
          execute :rm, fetch(:wpcli_local_db_file)
        end
      else
        run_locally do
          local_tmp_file = fetch(:wpcli_local_db_file).gsub(/\.gz$/, "")
          execute :gunzip, "-c", fetch(:wpcli_local_db_file), ">", local_tmp_file
          execute :wp, :db, :import, local_tmp_file
          execute :rm, fetch(:wpcli_local_db_file), local_tmp_file
          if fetch(:wpcli_remote_urls).length > 0 || fetch(:wpcli_local_urls).length > 0
            if fetch(:wpcli_remote_urls).length == fetch(:wpcli_local_urls).length
              fetch(:wpcli_remote_urls).each_with_index do |url, i|
                execute :wp, "search-replace", url, fetch(:wpcli_local_urls)[i], fetch(:wpcli_args) || "--skip-columns=guid", "--all-tables-with-prefix=wp"
                execute :wp, "search-replace", "https://#{fetch(:wpcli_local_urls)[i]}", "http://#{fetch(:wpcli_local_urls)[i]}", fetch(:wpcli_args) || "--skip-columns=guid", "--all-tables-with-prefix=wp"
              end
            else
              error = CommandError.new("remote_urls array and local_urls array not the same length")
              raise error
            end
          else
            execute :wp, "search-replace", fetch(:wpcli_remote_url), fetch(:wpcli_local_url), fetch(:wpcli_args) || "--skip-columns=guid", "--url=" + fetch(:wpcli_remote_url)
          end
        end
      end
    end

    desc "Push the local database"
    task :push do
      unless roles(:dev).empty?
        on roles(:dev) do
          within fetch(:dev_path) do
            execute :wp, :db, :export, "- |", :gzip, ">", fetch(:wpcli_local_db_file)
            download! fetch(:wpcli_local_db_file), fetch(:wpcli_local_db_file)
          end
        end
      else
        run_locally do
          execute :wp, :db, :export, "- |", :gzip, ">", fetch(:wpcli_local_db_file)
        end
      end
      on roles(:web) do
        upload! fetch(:wpcli_local_db_file), fetch(:wpcli_remote_db_file)
        within release_path do
          remote_tmp_file = fetch(:wpcli_remote_db_file).gsub(/\.gz$/, "")
          execute :gunzip, "-c", fetch(:wpcli_remote_db_file), ">", remote_tmp_file
          execute :wp, :db, :import, remote_tmp_file
          execute :rm, fetch(:wpcli_remote_db_file), remote_tmp_file
          if fetch(:wpcli_remote_urls).length > 0 || fetch(:wpcli_local_urls).length > 0
            if fetch(:wpcli_remote_urls).length == fetch(:wpcli_local_urls).length
              fetch(:wpcli_local_urls).each_with_index do |url, i|
                execute :wp, "search-replace", url, fetch(:wpcli_remote_urls)[i], fetch(:wpcli_args) || "--skip-columns=guid", "--all-tables-with-prefix=wp"
                execute :wp, "search-replace", "http://#{fetch(:wpcli_remote_urls)[i]}", "https://#{fetch(:wpcli_remote_urls)[i]}", fetch(:wpcli_args) || "--skip-columns=guid", "--all-tables-with-prefix=wp"
              end
            else
              error = CommandError.new("remote_urls array and local_urls array not the same length")
              raise error
            end
          else
            execute :wp, "search-replace", fetch(:wpcli_local_url), fetch(:wpcli_remote_url), fetch(:wpcli_args) || "--skip-columns=guid", "--url=" + fetch(:wpcli_local_url)
          end
        end
      end
      unless roles(:dev).empty?
        on roles(:dev) do
          within fetch(:dev_path) do
            execute :rm, fetch(:wpcli_local_db_file)
          end
        end
      end
      run_locally do
        execute :rm, fetch(:wpcli_local_db_file)
      end
    end

    namespace :backup do

      desc "Checking / Creating backup directory"
      task :create_backup_dir do
        run_locally do
          unless test("[ -d #{fetch(:wpcli_local_db_backup_dir)} ]")
            execute :mkdir, Pathname.new(fetch(:wpcli_local_db_backup_dir))
          end
        end
      end

      desc "Backup the remote database"
      task :remote do
        on roles(:web) do
          within release_path do
            execute :wp, :db, :export, "- |", :gzip, ">", fetch(:wpcli_remote_db_file)
            download! fetch(:wpcli_remote_db_file), File.join(fetch(:wpcli_local_db_backup_dir), fetch(:wpcli_local_db_backup_filename))
            execute :rm, fetch(:wpcli_remote_db_file)
          end
        end
      end

      desc "Backup the local database"
      task :local do
        run_locally do
          set :stage, :local
          execute :wp, :db, :export, "- |", :gzip, ">", File.join(fetch(:wpcli_local_db_backup_dir), fetch(:wpcli_local_db_backup_filename))
        end
      end

      before :push, 'backup:remote' if :wpcli_backup_db
      before :local, :create_backup_dir
      before :remote, :create_backup_dir

    end
  end
end
