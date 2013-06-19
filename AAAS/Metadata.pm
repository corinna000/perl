package AAAS::Metadata;

use strict;
use warnings;
use Carp;

sub new {
    my ($class, $issue, $page) = @_;
    my $self = {
        '_ISSUE'    =>  $issue,
        '_PAGE'     =>  $page,
    };

    bless   ($self, $class);

    $self->initialize();
    return  ($self);
}

sub initialize {
    use LWP::UserAgent;
    use AAAS::AnalyticsUtil;

    my $self   = shift(@_);
    my $issue  = $self->issue();
    my $page   = $self->page();
    my $volume = get_volume_number($issue);

    my $metadata_list = {
        'title'         =>  qr{meta\scontent="(.*?)"\s+name="citation_title"},
        'publisher'     =>  qr{meta\scontent="(.*?)"\s+name="DC[.]Publisher"},
        'date'          =>  qr{meta\scontent="(.*?)"\s+name="citation_date"},
        'doi'           =>  qr{meta\scontent="(.*?)"\s+name="citation_doi"},
        'pmid'          =>  qr{meta\scontent="(.*?)"\s+name="citation_pmid"},
        'contributors'  =>  qr{meta\scontent="(.*?)"\s+name="DC[.]Contributor"},
        'keywords'      =>  qr{cgi/collection/(.*?)"},
        'subject'       =>  qr{subject-headings.*?(?:\n)?.*?<li>(.*?)</li>},
        'lastpage'      =>  qr{cit-last-page">(.*?)</span>},
        'overline'      =>  qr{article-overline">(.*?)</span>},
        'pub_online'    =>  qr{slug-ahead-of-print-date">(.*?)</span>},
    };

    my $base_url = 'http://www.sciencemag.org/content';
    my $ua = LWP::UserAgent->new();
    my $url = "$base_url/$volume/$issue/$page.short";
    my $response = $ua->get($url) or croak "Could not reach website at $url .";
    my $code = $response->code;
    my $content = $response->content;
    ($code == 200) or 
        croak "Reached server, but encountered error $code retrieving page
        $url.\n $content";

    foreach my $type ( keys %{ $metadata_list } ) { 
        (@{$self->{$type}}) = ($content =~ m/$metadata_list->{$type}/xsg);
    }
    #use Data::Dumper;
    #print Dumper $self;
}

sub issue {
    my $self  = shift(@_);
    $self->{_ISSUE};
}

sub page {
    my $self  = shift(@_);
    $self->{_PAGE};
}

sub date {
    my $self  = shift(@_);
    $self->{date}[0];
}

sub doi {
    my $self  = shift(@_);
    $self->{doi}[0];
}

sub pmid {
    my $self  = shift(@_);
    $self->{pmid}[0];
}

sub authors {
    my $self  = shift(@_);
    $self->{contributors};
}

sub title {
    my $self  = shift(@_);
    $self->{title}[0];
}

sub keywords {
    my $self  = shift(@_);
    $self->{keywords};
}

sub publisher {
    my $self  = shift(@_);
    $self->{publisher}[0] ? $self->{publisher}[0] : 0;
}

sub subject {
    my $self  = shift(@_);
    $self->{subject}[0] ? $self->{subject}[0] : 0;
}

sub overline {
    my $self  = shift(@_);
    $self->{overline}[0] ? $self->{overline}[0] : 0;
}

sub lastpage {
    my $self  = shift(@_);
    $self->{lastpage}[0];
}

sub published_online {
    my $self  = shift(@_);
    $self->{pub_online}[0] ? $self->{pub_online}[0] : 0;
}

sub scopus {
    use AAAS::NetUtil;
    my $self = shift(@_);
    if (@_) {
        $self->{scopus} = shift(@_);
    }
    if (exists $self->{scopus}) {
        return $self->{scopus};
    }
    $self->{scopus} = 
        get_scopus_count (
            $self->{_ISSUE}, 
            $self->{_PAGE}, 
        );

    $self->{scopus};
}

sub isi {
    use AAAS::NetUtil;
    my $self = shift(@_);
    if (@_) {
        $self->{isi} = shift(@_);
    }
    if (exists $self->{isi}) {
        return $self->{isi};
    }
    $self->{isi} = 
        get_isi_count (
            $self->{_ISSUE}, 
            $self->{_PAGE}, 
        );

    $self->{isi};
}

sub citations {
    use AAAS::NetUtil;
    my $self = shift(@_);
    if (exists $self->{citations}) {
        return $self->{citations};
    }
    $self->{citations} = 
        get_citation_list (
            $self->{_ISSUE}, 
            $self->{_PAGE}, 
        );
    $self->{citations};
}

1;
