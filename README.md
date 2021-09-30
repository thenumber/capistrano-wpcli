# Capistrano::WPCLI

**Note: this plugin works only with Capistrano 3.**

Provides command line tools to facilitate Wordpress deploy.

## Multisite database support changes for The Number!
We have added some changes to allow wordpress search-replace to modify all domains and subdomains for wp multisites.

### Configuration
#### For Multisite
`:wp_cli_local_url` and `:wp_cli_remote_url` have been replaced with `:wp_cli_local_urls` and `:wp_cli_remote_urls` which take an array of domain names including subdomains, but **excluding** the protocol (`http://` or `https://`).
##### Important!
Your domains in `:wp_cli_local_urls` and `:wp_cli_remote_urls` arrays must be the same length. Since it subs out the each domain with the matching index on the other array.
##### Example:
In deploy.rb
```ruby
set :wp_cli_local_urls, ['sub.domain.test:8888', 'sub2.domain.test:8888', 'sub3.domain2.test:8888']
```
In production.rb
```ruby
set :wp_cli_remote_urls, ['sub.domain.com', 'sub2.domain.com', 'sub3.domain2.com']
```

### How it works
    wpcli:db:pull
1. Replaces your local db with a copy of the remote db (same as always)
2. Loops through `:wp_cli_remote_urls` array
3. Runs `wp search-replace` on the entire db changing all instances of `remote_url` value with `wp_cli_local_urls` value on the same index.
4. Runs `wp search-replace` to change the protocol from `https://` to `http://`. This has to be done seperately because there are a few places where the url is stored without the protocol and we want to catch those in our first search-replace.
- - -
    wpcli:db:push
1. Replaces your remote db with a copy of the local db (same as always)
2. Loops through `:wp_cli_local_urls` array
3. Runs `wp search-replace` on the entire db changing all instances of `local_url` value with `wp_cli_remote_url` value on the same index.
4. Runs `wp search-replace` to change the protocol from `http://` to `https://`. This has to be done seperately because there are a few places where the url is stored without the protocol and we want to catch those in our first search-replace.

#### For Single Site
Gem works the same as the default. (See below)

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'capistrano-wpcli', :git => 'https://github.com/thenumber/capistrano-wpcli'
```
And then execute:

    $ bundle

## Usage

All you need to do is put the following in `Capfile` file:

    require 'capistrano/wpcli'

### How it works (Tasks)

    wpcli:run

Executes the WP-CLI command passed as parameter.

    cap production wpcli:run["core language install fr_FR"]

- - -

    wpcli:db:push

Pushes the local WP database to the remote server and replaces the urls.

Optionally backs up the remote database before pushing (if `wpcli_backup_db` is set to true, see Configuration).

    cap production wpcli:db:push

- - -

    wpcli:db:pull

Pulls the remote server WP database to local and replaces the urls.

    cap production wpcli:db:pull

- - -

    wpcli:db:backup:remote

Pulls the remote server WP database to localhost, uses `wpcli_local_db_backup_dir` to define the location of the export.

- - -

    wpcli:db:backup:local

Backs up the local WP database to localhost, uses `wpcli_local_db_backup_dir` to define the location of the export.

- - -

    wpcli:rewrite:flush

Flush rewrite rules.

- - -

    wpcli:rewrite:hard_flush

Perform a hard flush - updates `.htaccess` rules as well as rewrite rules in database.

- - -

    wpcli:uploads:rsync:push

Push local uploads delta to remote machine using rsync.

- - -

    wpcli:uploads:rsync:pull

Pull remote uploads delta to local machine using rsync.

### Configuration

This plugin needs some configuration to work properly. You can put all your configs in Capistrano stage files i.e. `config/deploy/production.rb`.

Here's the list of options and the defaults for each option:

- - -

    set :wpcli_remote_url

Url of the WP root installation on the remote server (used by search-replace command).

- - -

    set :wpcli_local_url

Url of the WP root installation on the local server (used by search-replace command).

- - -

    set :local_tmp_dir

Absolute path to local directory temporary directory which is read and writeable.

Defaults to `/tmp`

- - -

    set :wpcli_backup_db

Set to true if you would like to create backups of databases on each push. Defaults to false.

- - -

    set :wpcli_local_db_backup_dir

Absolute or relative path to local directory for storing database backups which is read and writeable.

Defaults to `config/backup`

**IMPORTANT: Make sure to add the folder to .gitignore to prevent db backups from being in version control.**

- - -

    set :wpcli_args

You can pass arguments directly to WPCLI using this var.

Defaults to `ENV['WPCLI_ARGS']`

- - -

    set :wpcli_local_uploads_dir

Absolute or relative path to local WP uploads directory.

Defaults to `web/app/uploads/`.

**IMPORTANT: Add trailing slash!**

- - -

    set :wpcli_remote_uploads_dir

Absolute path to remote wordpress uploads directory.

Defaults to `#{shared_path.to_s}/web/app/uploads/`

**IMPORTANT: Add trailing slash!**

### FAQ

- What if i want to use a custom port for rsync?
  You can by setting your port somewhere inside the :ssh_options precedence.
  See here: http://capistranorb.com/documentation/advanced-features/properties/#precedence

### Vagrant

If you are using another machine as a development server (Vagrant for example), you should define a `dev` role and indicate the path where the project lives on that server. This normally goes on `deploy.rb` file. Here's an example:

    server "example.dev", user: 'vagrant', password: 'vagrant', roles: %w{dev}

    set :dev_path, '/srv/www/example.dev/current'

## Contributing

1. Fork it ( https://github.com/lavmeiker/capistrano-wpcli/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
