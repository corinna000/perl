package AAAS::NetUtil;

use warnings;
use strict;
use Carp;

require Exporter;

our @ISA=qw(Exporter);

our @EXPORT = qw{ connect_hwp 
                  get_citation_list
                  get_credentials 
                  get_isi_count
                  get_scopus_count
                  upload_hwp 
                  publish_hwp 
                  unique_urls
                  };

=head1 NAME

AAAS::NetUtil - A set of methods for connecting to Science live and
maintenance sites

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

my $password_file = q{k:\pl\workflow_scripts\astring.txt};
my $file_frag_pat = '.*[/](.*)$';
my $upload_url    =
    'http://hwmaint.sciencemag.org/newmaint/filemanager/uploadfile.cgi'; 
my $publish_url = 'http://hwmaint.sciencemag.org/newmaint/filemanager/publish.cgi?';
my $confirm_url = 'http://hwmaint.sciencemag.org/newmaint/filemanager/confirm_publish.cgi?';

=head1 SYNOPSIS

    use AAAS::NetUtil qw{
        connect_hwp
        get_credentials 
        publish_hwp 
        unique_urls
        upload_hwp 
    };

    connect_hwp
        my $hwp_ua = connect_hwp();

    get_credentials
        ${%credentials} = get_credentials();

    publish_hwp
        publish_hwp( 'preview_site/misc/test, $hwp_ua, @file_list );

    unique_urls
        @unique = unique_urls( @url_list );

    upload_hwp
        if ( upload_hwp( $remote_dir, $local_file, $hwp_ua ) );


=cut 

=head1 ERROR HANDLING

Most of the functions in this module have B<not> been rigorously tested for
boundary conditions, incorrect datatypes, etc. This is improving over time,
but in most cases a method will C<croak> out rather than quietly handle
exceptions. 



=head2 connect_hwp() 

=cut

sub connect_hwp {

    use LWP::UserAgent;

    my $hwp_credentials = get_credentials();

    my $hwpuseragent = LWP::UserAgent->new();

    $hwpuseragent->cookie_jar( {} );
    
    $hwpuseragent->default_header('Accept' => 'text/html');
    # fill out the authentication form

    my $response = $hwpuseragent->post( 
           'http://hwmaint.sciencemag.org/newmaint/filemanager/index.cgi?', [
                'normal_login'      => 'yes',
                'redirect_path'     => '',
                'redirect_query'    => '',
                'uri'               => '/newmaint/filemanager/index.cgi',
                'username'          => $hwp_credentials->{USERNAME},
                'code'              => $hwp_credentials->{PASSWORD},
                'signin'            => 'Sign In',
            ]

       );
   ($response->status_line =~ m{302}mxsi) 
        or croak "could not to server. Check the username and password and try again." . $response->content. "\n";
    return $hwpuseragent;
}

=head2 get_credentials 

=cut
sub get_credentials {
    my $hwp_credentials = {
        USERNAME => 'xxxx',
        PASSWORD => eval{ _get_password($password_file); },
    };
    return $hwp_credentials
}


=head2 get_password 

=cut

sub _get_password {

    my $pw_file = shift(@_);
    open (my $pw_fh, '<', $pw_file) or croak "Could not open password file."; 
    my $password = do { local $/; <$pw_fh>} ;
    #$password =~ s{.*?(\w+).*}{$1}xms;
    $password =~ s{\r\n}{}xms;
    return $password;
}

=head2 upload_hwp ($target_dir, $source_file, $hwp_ua)

=cut


sub upload_hwp {
    my $upload_dir = shift (@_) or croak "Upload path not specified. $!\n";
    my $file = shift (@_) or croak "File for upload not specified. $!\n";
    my $useragent = shift (@_) or connect_hwp();
    my $content = q{};

    # prepare filename for server
    (my $filename) = ($file =~ m{$file_frag_pat}xms);

    my $response = $useragent->post(
        $upload_url,
        Content_Type => 'form-data', 
        Content => [ 
            file_target   => $upload_dir, 
            uploaded_file   => [ $file ]
        ]
    );

    print "success\n" if ($response->content =~ m{success}mxs); 
    return;
}
=head2 publish_hwp ($target_dir, $hwp_ua, @file_list)

=cut
sub publish_hwp {
    my $upload_dir = shift(@_);
    my $useragent = shift(@_) or connect_hwp();
    my @files = @_;

    # convert full path to url-ready fragment in file list
    map(s|$file_frag_pat|file_list=$1|xms,@files);

    $upload_dir =~ s{[/]}{%2F}xms; 
    $upload_dir = "label=" . $upload_dir;

    my $index_url = "index_url=%2Fnewmaint%2Ffilemanager%2Findex.cgi";

    my $get_url = join('&',$publish_url,$upload_dir,@files,$index_url);
    
    my $publish_response = $useragent->get($get_url);

    ($publish_response->content =~ m{confirm\spublishing}xmsi) or 
        croak "could not submit for publishing. $publish_response->status_line\n";


    my $submit_confirm = 'Submit=CONFIRM';

    my $confirm_url = join('&',$confirm_url,$upload_dir,@files,$submit_confirm);

    my $confirm_response = $useragent->get($confirm_url);

    ($confirm_response->content =~ m{successfully\spublished}xmsi) or 
        croak "could not confirm publishing. $confirm_response->status_line\n";

    return;
}

=head2 unique_urls(@url_list) 

=cut

sub unique_urls {
    my (@issue_urls) = @_;

    # make the list unique
    my %duplicate = ();
    my @unique_urls = ();

    foreach my $url (@issue_urls) {
            unless ($duplicate{$url}) {
                $duplicate{$url} = 1;
                push (@unique_urls, $url);
            }
    } 

    return @unique_urls;
}


=head2 _get_citation($issue, $page, $type)

my $citations = _get_citation($issue, $page, $type);

=cut

sub _get_citation {
    use LWP::UserAgent;
    use AAAS::AnalyticsUtil;

    my $issue  = shift(@_);
    my $page   = shift(@_);  
    my $type   = shift(@_) or
        croak "Issue and page required for citation list.";
    my $volume = AAAS::AnalyticsUtil::get_volume_number($issue);
    my $type_baseurl =  {
        'list'       => 'http://www.sciencemag.org/cited-by/sci',
        'scopus'     => 'http://www.sciencemag.org/scopus-links/callback/sci',
        'isi'        => 'http://www.sciencemag.org/isi-links/sci/',
    };

    my $error_conditions = [
       qr{No Scopus Citing Articles},
       qr{No Citing Articles},
    ];

    my $url = "$type_baseurl->{$type}/$volume/$issue/$page";
    
    my $ua = LWP::UserAgent->new();
    my $response = $ua->get($url) or
        croak "Could not send request to $url.";
    my $content = $response->content;
    my $code    = $response->code;
    ($code == 200) or 
        croak "Reached server, but encountered an error retrieving page for
        $issue/$page. $code";

    foreach (@{$error_conditions}) {
        if ($content =~ m{$_}) {
            croak "An error occurred retriving citation for $issue/$page. $content";
        }
    }

    return $content;
}

=head2 get_citation_list($issue, $page)

my $citations = get_citation_list($issue, $page);

=cut

sub get_citation_list {
    my $issue = shift(@_);
    my $page  = shift(@_) or
        croak "Issue and page required for citation list.";

    return _get_citation($issue, $page, 'list');
}

=head2 get_scopus_count($issue, $page)

my $citations = get_citation_list($issue, $page);

=cut

sub get_scopus_count {
    my $issue = shift(@_);
    my $page  = shift(@_) or
        croak "Issue and page required for citation list.";

    my $citation = _get_citation($issue, $page, 'scopus');
    
    my ($scopus_count) = 
        ($citation =~ m{ \( (\d+) \) }xms);

    return $scopus_count;
}

=head2 get_isi_count($issue, $page)

my $citations = get_citation_list($issue, $page);

=cut

sub get_isi_count {
    my $issue = shift(@_);
    my $page  = shift(@_) or
        croak "Issue and page required for citation list.";

    my $citation = _get_citation($issue, $page, 'isi');
    
    my ($isi_count) = 
        ($citation =~ m{Science\s+ \( (\d+) \)}xms);

    return $isi_count;
}
=head1 AUTHOR

Corinna Cohn for Science, C<< <ccohn at aaas.org > >>

=head1 BUGS

Please report any bugs or feature requests to C<ccohn@aas.org>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AAAS::NetUtil


You can also look for information at:

=head1 ACKNOWLEDGEMENTS

=cut



1; # End of AAAS::NetUtil
