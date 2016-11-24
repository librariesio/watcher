# config valid only for current version of Capistrano
lock '3.6.1'

set :application, 'watcher'
set :repo_url, 'git@github.com:librariesio/watcher.git'

set :linked_files, fetch(:linked_files, []).push('.env')
