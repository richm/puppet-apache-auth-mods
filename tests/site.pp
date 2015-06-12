# this stuff is here to provide dependencies for the ipsilon stuff
package { 'keystone':
  ensure => present,
  name   => 'openstack-keystone',
  tag    => 'openstack',
}

group { 'keystone':
  ensure  => present,
  system  => true,
  require => Package['keystone'],
}

user { 'keystone':
  ensure  => 'present',
  gid     => 'keystone',
  system  => true,
  require => Package['keystone'],
}

file { '/etc/keystone/keystone.conf':
  ensure => present,
  owner  => 'keystone',
  group  => 'keystone',
  mode   => 0600,
}

keystone_config {
  'database/connection':   value => "mysql://keystone_admin:Secret12@localhost/keystone", secret => true;
}

class { '::apache':
  purge_configs => false,
}

class { '::keystone::wsgi::apache':
  ssl => false,
}

# ipsilon test begins
class { 'apache_auth::keystone_ipsilon':
  idp_url => 'https://ipa.rdodom.test/idp',
  idp_password => 'Secret12',
  saml_dir => '/etc/httpd/saml2/test',
  http_conf => '/etc/httpd/conf.d/keystone-mellon.conf',
  service => 'keystone',
  saml_base => '/v3',
  saml_auth => 'OS-FEDERATION/identity_providers/ipsilon/protocols/saml2/auth',
  saml_sp => 'mellon',
  saml_sp_logout => 'logout',
  saml_sp_postresp => 'postResponse',
  enable_ssl => false,
  sp_port => 5000,
}

apache_auth::keystone_ipsilon::vhost { 'main':
  http_conf   => '/etc/httpd/conf.d/keystone-mellon.conf',
  vhosts_name => 'keystone_wsgi_main',
  vhosts_file => '10-keystone_wsgi_main.conf',
  vhosts_port => '5000',
}
apache_auth::keystone_ipsilon::vhost { 'admin':
  http_conf   => '/etc/httpd/conf.d/keystone-mellon.conf',
  vhosts_name => 'keystone_wsgi_admin',
  vhosts_file => '10-keystone_wsgi_admin.conf',
  vhosts_port => '35357',
}
