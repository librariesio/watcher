# [Watcher](https://libraries.io/github/librariesio/watcher)

Ruby app for enqueuing sidekiq jobs for [Libraries.io](https://libraries.io) from package manager rss feeds.

## How it works

Watcher polls RSS feeds and JSON API endpoints from package manager registries every 30 seconds to check for new and updated packages.

When New/updated packages are seen, watcher enqueues jobs directly into the [Libraries.io](https://github.com/librariesio/libraries.io) sidekiq queue to download those packages.

It keeps a cache of the package updates it's seen recently to help reduce the load on the package manager registries and push new data into the system faster.

## Adding Support for a new feed

The code base is split into two separate sections, one for RSS/ATOM and one for JSON feeds.

For RSS feeds of new or recently updated packages then add each url to the `feeds` array, For JSON APIs then add each url to the `urls` array, along with the class name of the package, as listed in [`app/models/package_manager`](https://github.com/librariesio/libraries.io/tree/master/app/models/package_manager) in the Libraries.io main rails application.

## Development

Source hosted at [GitHub](http://github.com/librariesio/watcher).
Report issues/feature requests on [GitHub Issues](http://github.com/librariesio/watcher/issues). Follow us on Twitter [@librariesio](https://twitter.com/librariesio). We also hangout on [Gitter](https://gitter.im/librariesio/support).

### Getting Started

New to Ruby? No worries! You can follow these instructions to install a local server, or you can use the included Vagrant setup.

#### Installing a Local Server

First things first, you'll need to install Ruby 2.3.3. I recommend using the excellent [rbenv](https://github.com/sstephenson/rbenv),
and [ruby-build](https://github.com/sstephenson/ruby-build)

```bash
rbenv install 2.3.3
rbenv global 2.3.3
```

### Running the watcher

Start the watcher with the following command:

    bundle exec ruby watcher.rb

### Note on Patches/Pull Requests

 * Fork the project.
 * Make your feature addition or bug fix.
 * Add tests for it. This is important so I don't break it in a
   future version unintentionally.
 * Add documentation if necessary.
 * Commit, do not change procfile, version, or history.
 * Send a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2017 Andrew Nesbitt. See [LICENSE](https://github.com/librariesio/watcher/blob/master/LICENSE) for details.
