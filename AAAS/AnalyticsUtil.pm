package AAAS::AnalyticsUtil;

use warnings;
use strict;
use Carp;

require Exporter;

our @ISA=qw(Exporter);

our @EXPORT = qw{ 
                  coremetrics_load_h10  
                  coremetrics_volume_h10
                  coremetrics_issue_h10
                  coremetrics_manifest_h10
                  coremetrics_page_h10
                  coremetrics_pageviews_h10
                  get_volume_number
                  get_live_toc_response
                  get_maint_toc_response
                  _get_live_toc_url
                  _get_maint_toc_url
                  };
=head1 NAME

AAAS::AnalyticsUtil - A collection of methods for making queries against the
website, or for crawling site information for analysis. 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use AAAS::AnalyticsUtil;

    my $foo = AAAS::AnalyticsUtil->new();
    ...

    get_volume_number
        $volume = get_volume_number( $issue );



=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 get_maint_toc_response();

    get_maint_toc_response($issue);

    $html_content = get_maint_toc_response($issue);

    returns the raw HTML response from the hwmaint server

=cut

sub get_maint_toc_response {
    my $issue = shift(@_);
    use lib q{/home/ccohn/Perl/AAAS/AAAS-NetUtil/lib};

    use AAAS::NetUtil 'connect_hwp';

    my $toc_url = _get_maint_toc_url( $issue );

    my $hwp_ua = connect_hwp();

    my $response = $hwp_ua->get( $toc_url ) or
        croak "Could not reach server at $toc_url\n";

    ($response->code == 200) or 
        croak "Reached server, but encountered an error retrieving page.";
        
    return $response->content;
}
=head2 get_live_toc_response();

    get_live_toc_response($issue);

    $html_content = get_live_toc_response($issue);

    returns the raw HTML response from the server

=cut

sub get_live_toc_response {
    require LWP;
    # ---- 
    my $issue = shift(@_);
    my $toc_url = _get_live_toc_url( $issue );

    my $user_agent = new LWP::UserAgent();

    my $response = $user_agent->get( $toc_url ) or
        croak "Could not reach server at $toc_url\n";

    ($response->code == 200) or 
        croak "Reached server, but encountered an error retrieving page.";
        
    return $response->content;
}

=head2 _get_maint_toc_url();

    $toc_url = _get_maint_toc_url( $issue );

    This is reliable for TOCs from about 2001 forward, but will return
    unusable URLs without error for volumes < 299

=cut

sub _get_maint_toc_url {
    my $issue = shift(@_);
    my $toc_base_url = 'http://hwmaint.sciencemag.org/content/';

    my $volume = get_volume_number( $issue );

    $volume = "vol$volume/";
    $issue  = "issue$issue/";

    my $toc_url = $toc_base_url . $volume . $issue . "index.dtl";

    return $toc_url;
}


=head2 _get_live_toc_url();

    $toc_url = _get_live_toc_url( $issue );

    This is reliable for TOCs from about 2001 forward, but will return
    unusable URLs without error for volumes < 299

    This is a limitation of the issue_data textfile. If the textfile is
    updated with the whole 
=cut

sub _get_live_toc_url {
    my $issue = shift(@_);
    my $toc_base_url = 'http://www.sciencemag.org/content/';

    my $volume = get_volume_number( $issue );
    
    $volume = "$volume/";

    my $toc_url = $toc_base_url . $volume . $issue . ".toc";

    return $toc_url;
}

=head2 get_volume_number()

    get_volume_number($issuenumber) 

=cut

sub get_volume_number {
    my ($issue) = shift(@_);

    open (my $issue_file_handle, '<', "k:/pl/workflow_scripts/dates_iss_vol/issueData_xtnd.txt")
        or croak "Could not read the issueData_xtnd.txt file. $@";
    while (my $line = <$issue_file_handle>) {
        $line =~ s{\r\n}{}xms;
        if ($line =~ m/$issue/) {
            $line = substr($line, -3);
            close $issue_file_handle;
            return $line;
        }
    }
    croak "could not find volume number for issue $issue\n";
}


=head2 coremetrics_load_h10() 
        
        Parses a Coremetrics log file and returns a hashref structured by
        volume, issue, and page number.
        Given a delimited file of volume, issue, and page numbers, returns
        a defined subset of matched elements.

        This version is designed to work with the url format used on the 
        HWP H10 platform. For logs after November 16th, 2010, use
        C<coremetrics_match_h20()>.

        my @matches = coremetrics_load_h10( $log_file);

        my @matches = coremetrics_load_h10( $log_file, $list_file );

=cut

sub coremetrics_load_h10 {

    my $log_file = shift(@_);
    my $list_file = shift(@_);


    open (my $log_fh, '<', $log_file) or
        croak "Could not open source $log_file.\n";
    
    my $vol_list;

    while (<$log_fh>) {
        my $line = $_;
        $line =~ s{\r\n}{}xms;
        (my $vol, my $iss, my $page) = 
            ($line =~ m{
                        /cgi/\w+
                        (?:/\w+)?/
                        (\d+)/(\d+)/(\d+).*?, # path
                }xmsg);
        if ( defined ($page) ) {
            push @{ $vol_list->{$vol}->{$iss}->{$page} }, $line;
        }
    }

    # Autovivification makes it so I have to copy the parts of the whole
    # $vol_list that I need instead of just adding parts to the $vol_list 
    # that I want to keep. 
    if ( defined $list_file ) {

        open (my $source_fh, '<', $list_file) or 
            croak "Could not open source $list_file.\n";

        my $selected_list;
        while (<$source_fh>) {
            my $line = $_;
            (my $vol, my $iss, my $page) = split("\t",$_);
            $page =~ s{\r\n}{}xms;
            if ($vol_list->{$vol}->{$iss}->{$page}) {
                $selected_list->{$vol}->{$iss}->{$page} =
                $vol_list->{$vol}->{$iss}->{$page};
            }
        }
    return $selected_list;
    }
return $vol_list;
}

=head2 coremetrics_manifest_h10()

    my @manifest = coremetrics_manifest($cm_load)

    Takes a $cm_load and returns an array of comma-separated values for 
    volume,issue,page.

=cut

sub coremetrics_manifest_h10 {
    my $cm_log = shift(@_) or croak "A coremetrics logfile is required for
    this function.";

    my @manifest; 

    foreach my $vkey (keys %{ $cm_log }) {
        foreach my $ikey (keys %{ $cm_log->{$vkey} }) {
            foreach my $pkey (keys %{ $cm_log->{$vkey}->{$ikey} }) {
                push (@manifest, "$vkey,$ikey,$pkey");
            }
        }
    }
    return @manifest;
}


=head2 coremetrics_volume_h10()

    my %volume = coremetrics_volume_h10($vol, $cm_load)

    returns all the matches for that volume, takes a volume number and
    coremetrics_load_h10 hashref as arguments. 

=cut

sub coremetrics_volume_h10 {
    my $volume = shift(@_);
    my $cm_ref = shift(@_);

    return $cm_ref->{$volume}; 
}

=head2 coremetrics_issue_h10()

    my %pages = coremetrics_issue_h10($issue, $cm_load)

    returns all the matches for that volume. 

=cut

sub coremetrics_issue_h10 {
    my $issue = shift(@_);
    my $cm_ref = shift(@_);

    my $volume = get_volume_number($issue);

    return $cm_ref->{$volume}{$issue}; 
}


=head2 coremetrics_page_h10()

    my @pages = coremetrics_page_h10($issue, $page, $load, <$type>)

    returns all the matches for that page. 
    types: 
        abstract    => abstract, short
        pdf         => reprint, pdf
        full        => full
        somindex    => /DC1...
        som         => /DC1/1...
        figures     => /F1...
        tables      => /T1...y:w
=cut

sub coremetrics_page_h10 {
    my $issue    = shift(@_);
    my $page     = shift(@_);
    my $cm_ref   = shift(@_);
    my $pagetype = shift(@_);

    my $volume = get_volume_number($issue);

    my $search_options = {
        'abstract' => qr{(?:abstract|short)/$volume},
        'full'     => qr{full/$volume/$issue/$page[^/]},
        'pdf'      => qr{reprint/$volume},
        'somindex' => qr{$page/DC\d[^/]},
        'som'      => qr{$page/DC\d/]},
        'figures'  => qr{$page/F\d/]},
        'tables'   => qr{$page/T\d/]},
        'all'      => qr{.*},
    };

    my @pages = @{ $cm_ref->{$volume}{$issue}{$page} };

    if ( defined( $pagetype ) ) {
        my @filtered_pages = grep (/$search_options->{$pagetype}/, @pages);
        return @filtered_pages;
    }

    return @pages;
}


=head2 coremetrics_pageviews_interval_h10()

    @pageviews = coremetrics_pageviews_interval_h10($issue, $page, $load, $type)

    returns the pagviews for a content type over an interval. The last field
    is the total pageviews over the interval.

    The optional C<$type> limits the page to its content type:

    abstract
    full
    pdf
    somindex
    som
    figures
    tables
    all


=cut

sub coremetrics_pageviews_h10 {
    my $issue    = shift(@_);
    my $page     = shift(@_);
    my $cm_ref   = shift(@_);
    my $pagetype = shift(@_) || 'all';

    my $volume = get_volume_number($issue);

    my $search_options = {
        'abstract' => qr{(?:abstract|short)/$volume},
        'full'     => qr{full/$volume/$issue/$page[^/]},
        'pdf'      => qr{reprint/$volume},
        'somindex' => qr{$page/DC\d[^/]},
        'som'      => qr{$page/DC\d/]},
        'figures'  => qr{$page/F\d/]},
        'tables'   => qr{$page/T\d/]},
        'all'      => qr{.*},
    };

    my @pages = @{ $cm_ref->{$volume}{$issue}{$page} };

    my @filtered_pages = grep (/$search_options->{$pagetype}/, @pages);

    #use Data::Dumper;
    #print Dumper @filtered_pages;
    
    #my $field_cnt = @{[ $filtered_pages[0] =~ m{[,]}xmsg ]} + 1;

    #my $page_totals->[0 .. $field_cnt] = 0;
    my $page_totals = [$pagetype,];
    my $total_pageviews = 0; 

    foreach (@filtered_pages) {

    #combine each page into a single type and total all the pages views
    #for each interval
        my @fields = split(',', $_);

        for my $i (1.. ( scalar @fields - 1) ) {
        #for my $i (1..5) {
            if (not defined($page_totals->[$i]) ) {
                push (@{$page_totals}, int 0);
            }
            $page_totals->[$i] += $fields[$i];
            $total_pageviews += $fields[$i];
        }

    }
    push (@{$page_totals}, $total_pageviews);
    return $page_totals;
}


=head1 AUTHOR

Corinna Cohn for Science, C<< <ccohn at aaas.org > >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-aaas-analyticsutil at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AAAS-AnalyticsUtil>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AAAS::AnalyticsUtil


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AAAS-AnalyticsUtil>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AAAS-AnalyticsUtil>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AAAS-AnalyticsUtil>

=item * Search CPAN

L<http://search.cpan.org/dist/AAAS-AnalyticsUtil/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Corinna Cohn for Science.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of AAAS::AnalyticsUtil
