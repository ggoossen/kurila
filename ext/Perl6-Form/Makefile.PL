
use ExtUtils::MakeMaker;
WriteMakefile(
		NAME	=> q[Perl6::Form],
		VERSION => q[0.04],
        AUTHOR  => 'Damian Conway',
                MAN3PODS 	=> {}, 	# Pods will be built by installman.
		# PREREQ_PM => { Scalar::Util=>0, List::Util=>0 },

	     );
