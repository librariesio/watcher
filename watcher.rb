require 'bundler'
Bundler.require
Dotenv.load

MEMCACHED_OPTIONS = {
  server: (ENV["MEMCACHIER_SERVERS"] || "localhost:11211").split(","),
  username: ENV["MEMCACHIER_USERNAME"],
  password: ENV["MEMCACHIER_PASSWORD"],
  failover: true,
  socket_timeout: 1.5,
  socket_failure_delay: 0.2
}

def follow_feed(url, platform)
  client = Feedtosis::Client.new(url, backend: Moneta.new(:MemcachedDalli, MEMCACHED_OPTIONS.dup))
  while(true) do
    begin
      new_entries = client.fetch.new_entries
      if new_entries
        new_entries.each do |entry|
          begin
            name = nil
            if platform == 'Pub' && entry.title
              name = entry.title.split(' ').last
            elsif platform == 'CocoaPods' && entry.title
              name = entry.title.split(' ')[1]
            elsif entry.title
              name = entry.title.split(' ').first
            end
            if name
              puts "#{platform}/#{name}"
              Sidekiq::Client.push('queue' => 'default', 'class' => 'RepositoryDownloadWorker', 'args' => [platform, name])
            end
          rescue => exception
            p entry
            p exception
          end
        end
      end
    rescue
      nil
    end
    sleep 30
  end
end

threads = []

feeds = [
  ['http://registry.npmjs.org/-/rss?descending=true&limit=50', 'NPM'],
  ['http://packagist.org/feeds/releases.rss', 'Packagist'],
  ['http://packagist.org/feeds/packages.rss', 'Packagist'],
  ['http://hackage.haskell.org/packages/recent.rss', 'Hackage'],
  ['http://lib.haxe.org/rss/', 'Haxelib'],
  ['http://pypi.python.org/pypi?%3Aaction=rss', 'Pypi'],
  ['http://pypi.python.org/pypi?%3Aaction=packages_rss', 'Pypi'],
  ['http://pub.dartlang.org/feed.atom', 'Pub'],
  ['http://melpa.org/updates.rss', 'Emacs'],
  ['http://cocoapods.libraries.io/feed.rss', 'CocoaPods']
]
feeds.each do |feed|
  threads << Thread.new do
    follow_feed(feed[0], feed[1])
  end
end

def follow_json(url, platform)
  dc = Dalli::Client.new(MEMCACHED_OPTIONS[:server], MEMCACHED_OPTIONS.select {|k,v| k != :server })
  while(true) do
    update_names = dc.fetch(url) { [] }

    begin
      request = Curl::Easy.perform(url) do |curl|
        curl.headers["User-Agent"] = "Libraries.io Watcher"
      end

      json = JSON.parse(request.body_str)

      if platform == 'Elm'
        names = json
      elsif platform == 'Cargo'
        updated_names = json['just_updated'].map{|c| c['name']}
        new_names = json['new_crates'].map{|c| c['name']}
        names = (updated_names + new_names).uniq
      elsif platform == 'CPAN'
        names = json['hits']['hits'].map{|project| project['fields']['distribution'] }.uniq
      else
        names = json.map{|g| g['name']}.uniq
      end

      (names - update_names).each do |name|
        puts "#{platform}/#{name}"
        Sidekiq::Client.push('queue' => 'default', 'class' => 'RepositoryDownloadWorker', 'args' => [platform, name])
      end

      dc.set(url, names)
    rescue => exception
      p entry
      p exception
    end
    sleep 30
  end
end

urls = [
  ['https://rubygems.org/api/v1/activity/just_updated.json', 'Rubygems'],
  ['https://rubygems.org/api/v1/activity/latest.json', 'Rubygems'],
  ['https://atom.io/api/packages?page=1&sort=created_at&direction=desc', 'Atom'],
  ['https://atom.io/api/packages?page=1&sort=updated_at&direction=desc', 'Atom'],
  ['http://package.elm-lang.org/new-packages', 'Elm'],
  ['https://crates.io/summary', 'Cargo'],
  ['http://api.metacpan.org/v0/release/_search?q=status:latest&fields=distribution&sort=date:desc&size=100', 'CPAN'],
  ['https://hex.pm/api/packages?sort=inserted_at', 'Hex'],
  ['https://hex.pm/api/packages?sort=updated_at', 'Hex']
]

urls.each do |url|
  threads << Thread.new do
    follow_json(url[0], url[1])
  end
end

threads.each { |thr| thr.join }
