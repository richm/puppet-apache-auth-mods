define apache_auth::keystone_ipsilon::vhost (
  $http_conf   = '/etc/httpd/conf.d/keystone-mellon.conf',
  $vhosts_name = 'keystone_wsgi_main',
  $vhosts_file = '10-keystone_wsgi_main.conf',
  $vhosts_port = '5000'
) {
  ::concat::fragment { "${vhosts_name}-auth_mellon":
    target  => $vhosts_file,
    order   => 11,
    content => template('apache_auth/auth_mellon.conf.erb'),
    require => Exec['ipsilon-client-install'],
  }
}
