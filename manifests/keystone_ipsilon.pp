class apache_auth::keystone_ipsilon (
  $idp_url, # where to post to register our service
  $idp_password,
  $saml_dir = undef,
  $http_conf = '/etc/httpd/conf.d/keystone-mellon.conf',
  $service = 'keystone',
  $saml_base = '/v3',
  $saml_auth = 'OS-FEDERATION/identity_providers/ipsilon/protocols/saml2/auth',
  $saml_sp = 'mellon',
  $saml_sp_logout = 'logout',
  $saml_sp_postresp = 'postResponse',
  $enable_ssl = true,
  $sp_port = '5000', # only used when enable_ssl true
)
{
  include ::stdlib
  include ::apache
  include ::apache::mod::headers
  include apache_auth::mod::auth_mellon

  $real_saml_dir = pick($saml_dir, "/etc/httpd/saml2/${::fqdn}")
  $entity_xml = "${real_saml_dir}/metadata.xml"
  $entity_cert = "${real_saml_dir}/certificate.pem"
  $entity_key = "${real_saml_dir}/certificate.key"
  $idp_metadata = "${real_saml_dir}/idp-metadata.xml"
  $real_saml_auth = $saml_auth ? {
    /^\// => $saml_auth, # absolute path - just use it outright
    default => "${saml_base}/${saml_auth}" # relative to saml_base
  }
  $real_saml_sp = $saml_sp ? {
    /^\// => $saml_sp, # absolute path - just use it outright
    default => "${real_saml_auth}/${saml_sp}" # relative to saml_auth
  }
  $real_saml_sp_logout = $saml_sp_logout ? {
    /^\// => $saml_sp_logout, # absolute path - just use it outright
    default => "${real_saml_sp}/${saml_sp_logout}" # relative to saml_sp
  }
  $real_saml_sp_postresp = $saml_sp_postresp ? {
    /^\// => $saml_sp_postresp, # absolute path - just use it outright
    default => "${real_saml_sp}/${saml_sp_postresp}" # relative to saml_sp
  }
  if $enable_ssl {
    $secure_opt = '--saml-secure-setup'
  } else {
    $secure_opt = '--saml-insecure-setup'
  }

  package { 'ipsilon-client': }
  # also creates [$real_saml_dir, $entity_xml, $entity_cert, $entity_key, $idp_metadata, $http_conf]
  exec { 'ipsilon-client-install':
    command     => "ipsilon-client-install --saml-sp-name ${service} --port ${sp_port} \
                    --saml-base ${saml_base} --saml-auth ${real_saml_auth} \
                    --saml-sp ${real_saml_sp} --saml-idp-url ${idp_url} \
                    --saml-sp-logout ${real_saml_sp_logout} --saml-sp-post ${real_saml_sp_postresp} \
                    ${secure_opt} --http-saml-conf-file ${http_conf}",
    environment => "IPSILON_ADMIN_PASSWORD=$idp_password",
    path        => '/share/ipsilon/ipsilon/install:/usr/bin',
    creates     => $http_conf,
    require     => Package['ipsilon-client'],
  }
  keystone_config {
    'federation/driver':        value => 'keystone.contrib.federation.backends.sql.Federation';
    'auth/methods':             value => 'external,password,token,saml2';
    'auth/saml2':               value => 'keystone.auth.plugins.mapped.Mapped';
    'paste_deploy/config_file': value => '/etc/keystone/keystone-paste.ini';
  }
  file { '/etc/keystone/keystone-paste.ini':
    source  => '/usr/share/keystone/keystone-dist-paste.ini',
    owner   => 'keystone',
    group   => 'keystone',
    mode    => '0600',
    require => File['/etc/keystone/keystone.conf'],
  }

  # In the [pipeline:api_v3] section, see if the line beginning with pipeline contains
  # the federation_extension.  If it does, fine.  If it does not, add it just before
  # the service_v3.  service_v3 must always exist and should always be the last element
  # in the pipeline.
  # NOTE: I could not figure out how to use augeas with this file.  The file has
  # parameter names that begin with /, which causes all of the ini-style lenses to
  # choke.  But fortunately, sed.
  $pipeline_pattern = '\[pipeline:api_v3\]'
  exec { 'federation pipeline':
    command => "sed -i '/^${pipeline_pattern}/,/^$/ { \
                  /^pipeline/ { \
                    / federation_extension /n ; \
                    s/ service_v3/ federation_extension service_v3/ \
                  } \
                }' \
                /etc/keystone/keystone-paste.ini",
    path    => '/bin:/usr/bin',
    require => File['/etc/keystone/keystone-paste.ini'],
  }

  Exec['federation pipeline'] ~> Service<| title == 'httpd' |>

  exec { 'keystone-manage db_sync --extension federation':
    path        => '/usr/bin',
    user        => 'keystone',
#    refreshonly => true,
    subscribe   => [Package['keystone'], Keystone_config['database/connection']],
    require     => User['keystone'],
  }

  Exec['keystone-manage db_sync --extension federation'] ~> Service<| title == 'httpd' |>
}
