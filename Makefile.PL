use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'WWW::Nike::NikePlus',
    VERSION_FROM      => 'lib/WWW/Nike/NikePlus.pm', # finds $VERSION
    PREREQ_PM         => { 	LWP::Simple::Cookies => 0,
							Time::Duration => 0,
							LWP::Simple => 0,
							XML::Simple => 0,
							URI => 0,
    			     }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/WWW/Nike/NikePlus.pm', # retrieve abstract from module
       AUTHOR         => 'Alex Lomas <alexlomas at cpan dot org>') : ()),
);
