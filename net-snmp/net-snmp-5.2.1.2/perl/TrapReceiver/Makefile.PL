use ExtUtils::MakeMaker;
require 5;
use Config;
use Getopt::Long;
my %MakeParams = ();

%MakeParams = InitMakeParams();

WriteMakefile(%MakeParams);

if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw(NETSNMPTRAPD_AUTH_HANDLER NETSNMPTRAPD_HANDLER_BREAK
		 NETSNMPTRAPD_HANDLER_FAIL NETSNMPTRAPD_HANDLER_FINISH
		 NETSNMPTRAPD_HANDLER_OK NETSNMPTRAPD_POST_HANDLER
		 NETSNMPTRAPD_PRE_HANDLER));
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'NetSNMP::TrapReceiver',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'IV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

} else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}

sub InitMakeParams {
    my $opts;
    my %Params = (
		  'NAME'		=> 'NetSNMP::TrapReceiver',
		  'VERSION_FROM'	=> 'TrapReceiver.pm', # finds $VERSION
		  'XSPROTOARG'          => '-prototypes',
		  'PREREQ_PM'		=> { NetSNMP::OID => 5.1 },
		  ($] >= 5.005 ? ## Add these new keywords supported since 5.005
		   (ABSTRACT_FROM => 'TrapReceiver.pm',
		    AUTHOR        =>
		    'W. Hardaker <hardaker@users.sourceforge.net>') : ()),
		  'INC'		=> '-I.', # e.g., '-I. -I/usr/include/other'
		 );


    if ($ENV{'OSTYPE'} eq 'msys') {
      $Params{'DEFINE'} = "-DMINGW_PERL";
    }

    my ($snmp_lib, $snmp_llib, $sep);
    if (($Config{'osname'} eq 'MSWin32' && $ENV{'OSTYPE'} ne 'msys')) {
      $opts = NetSNMPGetOpts();	
      $Params{'DEFINE'} = "-DMSVC_PERL";
      $sep = '\\';
      $snmp_lib_file = 'netsnmp.lib';
      $snmp_link_lib = 'netsnmp';
      $agent_link_lib = 'netsnmpagent';
      $helpers_link_lib = 'netsnmphelpers';
      $mibs_link_lib = 'netsnmpmibs';
      $trapd_link_lib = 'netsnmptrapd';

      if (lc($opts->{'debug'}) eq "true") {
        $lib_dir = 'lib\\debug';
      }
      else {
        $lib_dir = 'lib\\release';
      }
    
      if (lc($opts->{'insource'}) eq "true") {
	$Params{'LIBS'} = "-L$basedir\\win32\\$lib_dir\\ -l$snmp_link_lib -l$agent_link_lib -l$helpers_link_lib " .
                "-l$mibs_link_lib -l$trapd_link_lib ";
      }
      else {
	my @LibDirs = split (';',$ENV{LIB});
        my $LibDir;
	if ($opts->{'prefix'}) {
	  push (@LibDirs,"$ENV{'NET-SNMP-PATH'}${sep}lib");
	}
	$noLibDir = 1;
	while ($noLibDir) {
	  $LibDir = find_files(["$snmp_lib_file"],\@LibDirs);
	  if ($LibDir ne '') {
	    $noLibDir = 0;
            # Put quotes around LibDir to allow spaces in paths
            $LibDir = '"' . $LibDir . '"';          
	  }
	  else
	  {
	    @LibDirs = ();
	    @LibDirs[0] = prompt("The Net-SNMP library ($snmp_lib_file) could not be found.\nPlease enter the directory where it is located:");
	    @LibDirs[0] =~ s/\\$//;
	  }
	}
	$Params{LIBS} = "-L$LibDir -l$snmp_link_lib -l$agent_link_lib -l$helpers_link_lib -l$mibs_link_lib -l$trapd_link_lib ";
      }

      $Params{'INC'} = "-I$basedir\\include\\ -I$basedir\\include\\net-snmp\\ -I$basedir\\win32\\ ";
    }
    else {
	$opts = NetSNMPGetOpts();

	if (!$ENV{'NETSNMP_CCFLAGS'}) {
	    $Params{'CCFLAGS'} = `$opts->{'nsconfig'} --cflags`;
	    chomp($Params{'CCFLAGS'});
	    $Params{'CCFLAGS'} .= " " . $Config{'ccflags'};
	} else {
	    $Params{'CCFLAGS'} = $ENV{'NETSNMP_CCFLAGS'};
	}

	if (lc($opts->{'insource'}) eq "true") {
	    $Params{'CCFLAGS'} = "-I../../include " . $Params{'CCFLAGS'};
	}

	$Params{'CCFLAGS'} =~ s/ -W[-\w]+//g; # ignore developer warnings
	if ($Params{'CCFLAGS'} eq "") {
	    die "You need to install net-snmp first (I can't find net-snmp-config)";
	}
    }

    return(%Params);
}
# common subroutines -- DO NOT EDIT.
# They are imported from the Makefile.subs.pl file
sub NetSNMPGetOpts {
    my %ret;
    my $rootpath = shift;
    $rootpath = "../" if (!$rootpath);
    $rootpath .= '/' if ($rootpath !~ /\/$/);

    if (($Config{'osname'} eq 'MSWin32' && $ENV{'OSTYPE'} ne 'msys')) {

      # Grab command line options first.  Only used if environment variables are not set
      GetOptions("NET-SNMP-IN-SOURCE=s" => \$ret{'insource'},
        "NET-SNMP-PATH=s"      => \$ret{'prefix'},
        "NET-SNMP-DEBUG=s"     => \$ret{'debug'});

      if ($ENV{'NET-SNMP-IN-SOURCE'})
      {
	$ret{'insource'} = $ENV{'NET-SNMP-IN-SOURCE'};
        undef ($ret{'prefix'});
      }
      elsif ($ENV{'NET-SNMP-PATH'})
      {
	$ret{'prefix'} = $ENV{'NET-SNMP-PATH'};
      }

      if ($ENV{'NET-SNMP-DEBUG'})
      {
	$ret{'debug'} = $ENV{'NET-SNMP-DEBUG'};
      }

      # Update environment variables in case they are needed
      $ENV{'NET-SNMP-IN-SOURCE'}    = $ret{'insource'};
      $ENV{'NET-SNMP-PATH'}         = $ret{'prefix'};
      $ENV{'NET-SNMP-DEBUG'}        = $ret{'debug'};

      $basedir = `%COMSPEC% /c cd`;
      chomp $basedir;
      $basedir =~ /(.*?)\\perl.*/;
      $basedir = $1;
      print "Net-SNMP base directory: $basedir\n";

    }
    else
    {
      if ($ENV{'NET-SNMP-CONFIG'} &&
        $ENV{'NET-SNMP-IN-SOURCE'}) {
	# have env vars, pull from there
	$ret{'nsconfig'} = $ENV{'NET-SNMP-CONFIG'};
	$ret{'insource'} = $ENV{'NET-SNMP-IN-SOURCE'};
      } else {
	# don't have env vars, pull from command line and put there
	GetOptions("NET-SNMP-CONFIG=s" => \$ret{'nsconfig'},
	           "NET-SNMP-IN-SOURCE=s" => \$ret{'insource'});

	if (lc($ret{'insource'}) eq "true" && $ret{'nsconfig'} eq "") {
	    $ret{'nsconfig'}="sh ROOTPATH../net-snmp-config";
	} elsif ($ret{'nsconfig'} eq "") {
	    $ret{'nsconfig'}="net-snmp-config";
	}

	$ENV{'NET-SNMP-CONFIG'}    = $ret{'nsconfig'};
	$ENV{'NET-SNMP-IN-SOURCE'} = $ret{'insource'};
      }
    }	

    $ret{'nsconfig'} =~ s/ROOTPATH/$rootpath/;

    $ret{'rootpath'} = $rootpath;

    \%ret;
}

sub find_files {
    my($f,$d) = @_;
    my ($dir,$found,$file);
    for $dir (@$d){
	$found = 0;
	for $file (@$f) {
	    $found++ if -f "$dir/$file";
	}
	if ($found == @$f) {
	    return $dir;
	}
    }
}
