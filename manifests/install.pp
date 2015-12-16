# == Class puppet_agent::install
#
# This class is called from puppet_agent for install.
#
# === Parameters
#
# [package_file_name]
#   The puppet-agent package file name.
#   (see puppet_agent::prepare::package_file_name)
# [version]
#   The puppet-agent version to install.
#
class puppet_agent::install(
  $package_file_name = undef,
  $package_version   = 'present',
) {
  assert_private()

  if ($::operatingsystem == 'SLES' and $::operatingsystemmajrelease == '10') or ($::operatingsystem == 'AIX' and  $::architecture =~ /PowerPC_POWER[5,6,7]/) {
    contain puppet_agent::install::remove_packages

    exec { 'replace puppet.conf removed by package removal':
      path      => '/bin:/usr/bin:/sbin:/usr/sbin',
      command   => "cp ${puppet_agent::params::confdir}/puppet.conf.rpmsave ${puppet_agent::params::config}",
      creates   => $puppet_agent::params::config,
      require   => Class['puppet_agent::install::remove_packages'],
      before    => Package[$puppet_agent::package_name],
      logoutput => 'on_failure',
    }

    $_package_options = {
      provider        => 'rpm',
      source          => "/opt/puppetlabs/packages/${package_file_name}",
    }
  } elsif $::operatingsystem == 'Solaris' and $::operatingsystemmajrelease == '10' {
    contain puppet_agent::install::remove_packages

    $_unzipped_package_name = regsubst($package_file_name, '\.gz$', '')
    $_package_options = {
      adminfile => '/opt/puppetlabs/packages/solaris-noask',
      source    => "/opt/puppetlabs/packages/${_unzipped_package_name}",
      require   => Class['puppet_agent::install::remove_packages'],
    }
  } elsif $::operatingsystem == 'Solaris' and $::operatingsystemmajrelease == '11' {
    contain puppet_agent::install::remove_packages

    exec { 'puppet_agent restore /etc/puppetlabs':
      command => 'cp -r /tmp/puppet_agent/puppetlabs /etc',
      path    => '/bin:/usr/bin:/sbin:/usr/sbin',
      require => Class['puppet_agent::install::remove_packages'],
    }

    exec { 'puppet_agent post-install restore /etc/puppetlabs':
      command     => 'cp -r /tmp/puppet_agent/puppetlabs /etc',
      path        => '/bin:/usr/bin:/sbin:/usr/sbin',
      refreshonly => true,
    }

    $_package_options = {
      require => Exec['puppet_agent restore /etc/puppetlabs'],
      notify  => Exec['puppet_agent post-install restore /etc/puppetlabs'],
    }
  } elsif $::operatingsystem == 'Darwin' and $::macosx_productversion_major =~ /10\.[9,10,11]/ {
    contain puppet_agent::install::remove_packages

    $_package_options = {
      source    => "/opt/puppetlabs/packages/${package_file_name}",
      require   => Class['puppet_agent::install::remove_packages'],
    }
  } else {
    $_package_options = {}
  }

  if $::osfamily == 'windows' {
    # Prevent re-running the batch install
    if versioncmp("${::aio_agent_version}", "${package_version}") < 0 {
      if $::puppet_agent::is_pe == true and empty($::puppet_agent::source) and defined(File["${::puppet_agent::params::local_packages_dir}/${package_file_name}"]) {
        class { 'puppet_agent::windows::install':
          package_file_name => $package_file_name,
          source            => windows_native_path("${::puppet_agent::params::local_packages_dir}/${package_file_name}"),
        }
      } else {
        class { 'puppet_agent::windows::install':
          package_file_name => $package_file_name,
          source            => $::puppet_agent::source,
        }
      }
    }
  } elsif $::osfamily == 'Solaris' or $::osfamily == 'Darwin' or $::osfamily == 'AIX' or ($::operatingsystem == 'SLES' and $::operatingsystemmajrelease == '10') {
    # Solaris 10/OSX/AIX/SLES 10 package provider does not provide 'versionable'
    # Package is removed above, then re-added as the new version here.
    package { $::puppet_agent::package_name:
      ensure => 'present',
      *      => $_package_options,
    }
  } elsif ($::osfamily == 'RedHat') and ($package_version != 'present') {
    # Workaround PUP-5802/PUP-5025
    package { $::puppet_agent::package_name:
      ensure => "${package_version}-1.el${::operatingsystemmajrelease}",
      *      => $_package_options,
    }
  } elsif ($::osfamily == 'Debian') and ($package_version != 'present') {
    # Workaround PUP-5802/PUP-5025
    package { $::puppet_agent::package_name:
      ensure => "${package_version}-1${::lsbdistcodename}",
      *      => $_package_options,
    }
  } else {
    package { $::puppet_agent::package_name:
      ensure => $package_version,
      *      => $_package_options,
    }
  }
}
