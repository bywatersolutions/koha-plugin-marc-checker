package Koha::Plugin::Com::ByWaterSolutions::MarcChecker;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;

use MARC::Lint;
use MARC::File::USMARC;

## Here we set our plugin version
our $VERSION = 1.01;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Koha MARC Record Checker',
    author          => 'Kyle M Hall',
    description     => 'Checks your MARC records using MARC::Lint.',
    date_authored   => '2013-04-02',
    date_updated    => '2013-04-02',
    minimum_version => '3.1000000',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('output') ) {
        $self->report_step1();
    } else {
        $self->report_step2();
    }
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'report-step1.tt' } );

    print $cgi->header();
    print $template->output();
}

sub report_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $output = $cgi->param('output');

    my $biblionumber_starting = $cgi->param("biblionumber_starting");
    my $biblionumber_ending   = $cgi->param("biblionumber_ending");

    ( $biblionumber_starting, $biblionumber_ending ) = ( $biblionumber_ending, $biblionumber_starting ) if ( $biblionumber_starting > $biblionumber_ending );

    my $query = "
        SELECT * 
        FROM biblioitems bi
        LEFT JOIN biblio b ON bi.biblionumber = b.biblionumber
        WHERE b.biblionumber >= ? AND b.biblionumber <= ?
    ";
    my $sth = $dbh->prepare($query);
    $sth->execute( $biblionumber_starting, $biblionumber_ending );

    my $lint = new MARC::Lint;

    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
        my $marc = MARC::Record::new_from_usmarc( $row->{'marc'} );
        $lint->check_record($marc);
        my @warnings = $lint->warnings;

        push(
            @results,
            {   data     => $row,
                warnings => \@warnings,
            }
        );
    }

    my $template = $self->get_template( { file => "report-step2.tt" } );

    $template->param( results => \@results, );

    print $cgi->header();
    print $template->output();
}

1;
