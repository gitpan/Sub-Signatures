use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'		    => 'Sub::Signatures',
    'VERSION_FROM'	=> 'lib/Sub/Signatures.pm',
    'PREREQ_PM'		=> {
        'Filter::Simple'  => '0.78',
        'Test::Exception' => '0.20',
    },
    ($] >= 5.005
        ? (ABSTRACT_FROM => 'lib/Sub/Signatures.pm', AUTHOR => 'Curtis "Ovid" Poe')
        : ()
    ),
);
