  # Update the package repository before doing anything else to
  #   ensure we can install everything.
  exec {
    'initial package repository update':
      command => '/usr/bin/apt-get update';
  } -> Package <| |>


  # =========================
  # postgres stuff
  # =========================

  # db config
  #$database = loadyaml('/home/andrew/tmp/take2/database.yml')

  $database = {
    development => {
      database => 'development',
      username => 'test',
      password => 'test'
    },
    test => {
      database => 'test',
      username => 'test',
      password => 'test'
    }
  }

  # Install postgres.
  class {
    'postgresql::server':
      postgres_password => 'postgres';
  }

  class {
    'postgresql::server::postgis':
      package_name => 'postgresql-9.3-postgis-2.1';
  }

  # Needed for hstore extension.
  class { 'postgresql::server::contrib': }

  # Needed for pg gem.
  class { 'postgresql::lib::devel': }

  # Make the development database user.
  postgresql::server::role {
    $database[development][username]:
      superuser => true,
      password_hash => postgresql_password($database[development][username], $database[development][password]);
  }

  # Setup the test database user if it is not the same as the development user.
  if($database[test][username] != $database[development][username]) {
    postgresql::server::role {
      $database[test][username]:
        superuser => true,
        password_hash => postgresql_password($database[test][username], $database[test][password]);
    }
  }

  # Setup database server access.
  postgresql::server::pg_hba_rule {
    'allow postgres user access':
      order => 000,
      type => 'local',
      database => 'all',
      user => 'postgres',
      address => '',
      auth_method => 'peer';
    'allow development database user access':
      order => 000,
      type => 'local',
      database => 'all',
      user => $database[development][username],
      address => '',
      auth_method => 'md5';
  }

  # Setup database server access for the test database user.
  if($database[test][username] != $database[development][username]) {
    postgresql::server::pg_hba_rule {
      'allow test database user access':
        order => 000,
        type => 'local',
        database => 'all',
        user => $database[test][username],
        address => '',
        auth_method => 'md5';
    }
  }

  # Make the databases.
  postgresql::server::db {
    $database[test][database]:
      user     => $database[test][username],
      password => postgresql_password($database[test][username], $database[test][password]);
    $database[development][database]:
      user     => $database[development][username],
      password => postgresql_password($database[development][username], $database[development][password]);
  }

  # ==========================
  # ruby stuff
  # ==========================

  # install RVM
  include rvm
  # class { 'rvm': version => '1.26.9' }

  # # Install Ruby with RVM.
  rvm_system_ruby {
    'ruby-2.1.0':
      ensure => 'present',
      default_use => true;
  }

  package {
    # Needed to install gems from git repositories.
    'git':
      ensure => 'present';
    # Needed for execjs gem.
    'nodejs':
      ensure => 'present';
    # Nedded for sidekiq.
    'redis-server':
      ensure => 'present';
  }


  rvm_gemset {
    "ruby-2.1.0@global":
    ensure => 'present',
    require => Rvm_system_ruby['ruby-2.1.0'];
  }

  # essential gems
  rvm_gem {
    'ruby-2.1.0@global/bundler':
    ensure => latest,
    require => Rvm_system_ruby['ruby-2.1.0'];
  }

  rvm_gem {
    'ruby-2.1.0@global/puppet':
    ensure => latest,
    require => Rvm_system_ruby['ruby-2.1.0'];
  }
