server '163.172.159.178', user: 'root', roles: %w{app}

namespace :deploy do
  task :restart do
    on roles(:app) do |host|
      execute "restart watcher"
    end
  end
  after :publishing, :restart
end
