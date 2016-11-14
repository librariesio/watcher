require 'bundler'
Bundler.require

MEMCACHED_URL = ENV['MEMCACHED_URL'] || 'localhost:11211'

def follow_feed(url, platform)
  client = Feedtosis::Client.new(url, backend: Moneta.new(:MemcachedDalli, server: MEMCACHED_URL))
  while(true) do
    new_entries = client.fetch.new_entries
    if new_entries
      new_entries.each do |entry|
        name = entry.title.split(' ').first
        puts "#{platform}/#{name}"
        Sidekiq::Client.push('queue' => 'default', 'class' => 'RepositoryDownloadWorker', 'args' => [platform, name])
      end
    end
    sleep 30
  end
end

threads = []

feeds = [
  ['http://registry.npmjs.org/-/rss?descending=true&limit=50', 'npm'],
  ['http://packagist.org/feeds/releases.rss', 'composer'],
  ['http://packagist.org/feeds/packages.rss', 'composer'],
  ['http://hackage.haskell.org/packages/recent.rss', 'hackage'],
  ['http://lib.haxe.org/rss/', 'haxelib'],
  ['http://pypi.python.org/pypi?%3Aaction=rss', 'pypi'],
  ['http://pypi.python.org/pypi?%3Aaction=packages_rss', 'pypi']
]
feeds.each do |feed|
  threads << Thread.new do
    follow_feed(feed[0], feed[1])
  end
end

threads.each { |thr| thr.join }
