require 'bundler'
Bundler.require

MEMCACHED_OPTIONS = {
  server: (ENV["MEMCACHIER_SERVERS"] || "localhost:11211").split(","),
  username: ENV["MEMCACHIER_USERNAME"],
  password: ENV["MEMCACHIER_PASSWORD"],
  failover: true,
  socket_timeout: 1.5,
  socket_failure_delay: 0.2
}

def follow_feed(url, platform)
  client = Feedtosis::Client.new(url, backend: Moneta.new(:MemcachedDalli, MEMCACHED_OPTIONS))
  while(true) do
    new_entries = client.fetch.new_entries
    if new_entries
      new_entries.each do |entry|
        if platform == 'Pub'
          name = entry.title.split(' ').last
        elsif platform == 'CocoaPods'
          name = entry.title.split(' ')[1]
        else
          name = entry.title.split(' ').first
        end
        puts "#{platform}/#{name}"
        Sidekiq::Client.push('queue' => 'default', 'class' => 'RepositoryDownloadWorker', 'args' => [platform, name])
      end
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
  ['http://atom.io/packages.atom', 'Atom'],
  ['http://melpa.org/updates.rss', 'Emacs'],
  ['http://cocoapods.libraries.io/feed.rss', 'CocoaPods']
]
feeds.each do |feed|
  threads << Thread.new do
    follow_feed(feed[0], feed[1])
  end
end

def follow_rubygems_json(url)
  dc = ::Dalli::Client.new(MEMCACHED_OPTIONS[:server], MEMCACHED_OPTIONS.select {|k,v| k != :server })
  while(true) do
    update_names = dc.fetch(url) { [] }

    names = JSON.parse(Curl.get(url).body_str).map{|g| g['name']}.uniq

    (names - update_names).each do |name|
      puts "Rubygems/#{name}"
      Sidekiq::Client.push('queue' => 'default', 'class' => 'RepositoryDownloadWorker', 'args' => ['Rubygems', name])
    end

    dc.set(url, names)
    sleep 30
  end
end

threads << Thread.new do
  follow_rubygems_json('https://rubygems.org/api/v1/activity/just_updated.json')
end

threads << Thread.new do
  follow_rubygems_json('https://rubygems.org/api/v1/activity/latest.json')
end

threads.each { |thr| thr.join }
