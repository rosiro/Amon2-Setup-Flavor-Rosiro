package Amon2::Setup::Flavor::Rosiro;
use strict;
use warnings;
use 5.008001;
our $VERSION = '0.01';

use parent qw(Amon2::Setup::Flavor::Minimum);
use Amon2::Setup::Asset::jQuery;
use Amon2::Setup::Asset::BlueTrip;
use HTTP::Status qw/status_message/;
use utf8;
use File::Copy;

sub run {
    my $self = shift;
    $self->SUPER::run();
    $self->mkpath('static/images');
    $self->mkpath('static/javascript');
    $self->mkpath('static/css');
    $self->mkpath('lib/<< PATH >>/DB');
    $self->mkpath('lib/<< PATH >>/Web');
    $self->mkpath('lib/<< PATH >>/Web/C');
    $self->mkpath('lib/<< PATH >>/Web/M');
    $self->mkpath('script');
    $self->write_file('lib/<<PATH>>.pm', <<'...');
package <% $module %>;
use strict;
use warnings;
use parent qw/Amon2/;
our $VERSION='0.01';
use 5.008001;
use <% $module %>::DB;

sub db {
    my ($self, $c) = @_;
    if (!defined $self->{db}) {
        my $conf = $self->config->{'Teng'} or die "missing configuration for 'Teng'";
        my $dbh = DBI->connect($conf->{dsn}, $conf->{username}, $conf->{password}, $conf->{connect_options}) or "Cannot connect to DB:: " . $DBI::errstr;
        $self->{db} = Hello::DB->new({ dbh => $dbh });
    }
    return $self->{db};
}

# __PACKAGE__->load_plugin(qw//);

1;
...

$self->write_file("lib/<<PATH>>/Web/Dispatcher.pm",<<'...');
package <% $module %>::Web::Dispatcher;
use strict;
use warnings;
use Amon2::Web::Dispatcher::RouterSimple;

connect '/' => 'Root#index';
connect '/' => 'Root#default';

1;
...

$self->write_file("lib/<<PATH>>/Web/C/Root.pm",<<'...');
package <% $module %>::Web::C::Root;
use strict;
use warnings;
use utf8;

sub index {
    my ($class, $c) = @_;
}

sub default {
    my ($class, $c) = @_;
    $c->res->status(404);
    $c->res->body("404 Not Found");
}

1;

...

$self->write_file("lib/<<PATH>>/DB.pm",<<'...');
package <% $module %>::DB;
use parent 'Teng';

1;
...
    $self->write_file("script/make_schema.pl",<<'...');
use strict;
use warnings;
use utf8;
use DBI;
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '..', 'lib');
use lib File::Spec->catdir($FindBin::Bin, '..', 'extlib', 'lib', 'perl5');
use <% $module %>;
use Teng::Schema::Dumper;

my $c = <% $module %>->bootstrap;
my $conf = $c->config->{'Teng'};

my $dbh = DBI->connect($conf->{dsn}, $conf->{username}, $conf->{password}, $conf->{connect_options}) or die "Cannot connect to DB:: " . $DBI::errstr;
my $schema = Teng::Schema::Dumper->dump(dbh => $dbh, namespace => '<% $module %>::DB');

my $dest = File::Spec->catfile($FindBin::Bin, '..', 'lib', '<% $module %>', 'DB', 'Schema.pm');
open my $fh, '>', $dest or die "cannot open file '$dest': $!";
print {$fh} $schema;
close;
...

    $self->write_file('lib/<<PATH>>/Web.pm', <<'...');
package <% $module %>::Web;
use strict;
use warnings;
use parent qw/<% $module %> Amon2::Web/;
use File::Spec;

# load all controller classes
use Module::Find ();
Module::Find::useall("<% $module %>::Web::C");
Module::Find::useall("<% $module %>::Web::M");


# dispatcher
use <% $module %>::Web::Dispatcher;
sub dispatch {
    return <% $module %>::Web::Dispatcher->dispatch($_[0]) or die "response is not generated";
}

# setup view class
use Text::Xslate;
{
    my $view_conf = __PACKAGE__->config->{'Text::Xslate'} || +{};
    unless (exists $view_conf->{path}) {
        $view_conf->{path} = [ File::Spec->catdir(__PACKAGE__->base_dir(), 'tmpl') ];
    }
    my $view = Text::Xslate->new(+{
        'syntax'   => 'TTerse',
        'module'   => [ 'Text::Xslate::Bridge::TT2Like' ],
        'function' => {
            c => sub { Amon2->context() },
            uri_with => sub { Amon2->context()->req->uri_with(@_) },
            uri_for  => sub { Amon2->context()->uri_for(@_) },
        },
        %$view_conf
    });
    sub create_view { $view }
}

# load plugins
use HTTP::Session::Store::File;
__PACKAGE__->load_plugins(
    #'Web::FillInFormLite',
    'Web::NoCache', # do not cache the dynamic content by default
    'Web::CSRFDefender',
    'Web::HTTPSession' => {
        state => 'Cookie',
        store => HTTP::Session::Store::File->new(
            dir => File::Spec->tmpdir(),
        )
    },
);

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;
        $res->header( 'X-Content-Type-Options' => 'nosniff' );
    },
);

__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my ( $c ) = @_;
        # ...
        return;
    },
);

1;
...

    $self->write_file("config/development.pl", <<'...');
+{
    'DBI' => [
        'dbi:mysql:dbname=development.db',
        '',
        '',
        +{
	    mysql_enable_utf8 => '1',
        }
    ],
    'Text::Xslate' => +{},
};

};
...

    $self->write_file("config/deployment.pl", <<'...');
+{
    'DBI' => [
        'dbi:mysql:dbname=deployment.db',
        '',
        '',
        +{
	    mysql_enable_utf8 => '1',
        }
    ],
    'Text::Xslate' => +{},
};
...

    $self->write_file("config/test.pl", <<'...');
+{
    'DBI' => [
        'dbi:mysql:dbname=test.db',
        '',
        '',
        +{
	    mysql_enable_utf8 => '1',
        }
    ],
    'Text::Xslate' => +{},
};
...
    $self->write_file("sql/my.sql", '');
    $self->write_file("sql/sqlite3.sql", '');
$self->write_file("tmpl/index.tt",<<'...');
[% WRAPPER 'include/layout.tt' %]

<hr class="space">

<div class="span-15 colborder">
    <h1>Hello, Amon2 world!</h1>

    <h2>For benchmarkers...</h2>
    <p>If you want to benchmarking between Plack based web application frameworks, you should use <B>Amon2::Setup::Flavor::Minimum</B> instead.</p>
    <p>You can use it as following one liner:</p>
    <pre>% amon2-setup.pl --flavor Minimum <% $module %></pre>
</div>
<div class="span-8 last">
    <p>Amon2 is right for you if ...</p>
    <ul>
    <li>You need exceptional performance.</li>
    <li>You want a framework with a small footprint.</li>
    <li>You want a framework that requires nearly zero configuration.</li>
    </ul>
</div>

<hr class="space">

[% END %]
...
    $self->{jquery_min_basename} = Amon2::Setup::Asset::jQuery->jquery_min_basename();
$self->write_file('tmpl/include/layout.tt', <<'...');
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8" />
    <title>[% title || '<% $module %>' %]</title>
    <meta http-equiv="Content-Style-Type" content="text/css" />  
    <meta http-equiv="Content-Script-Type" content="text/javascript" />  
    <meta name="viewport" content="width=device-width, minimum-scale=1.0, maximum-scale=1.0"]]>
    <meta name="format-detection" content="telephone=no" />
    <link href="[% uri_for('/static/css/blueprint/screen.css') %]" rel="stylesheet" type="text/css" media="screen" />
    <link href="[% uri_for('/static/css/blueprint/print.css') %]" rel="stylesheet" type="text/css" media="print" />
    <!--[if lt IE 8]><link rel="stylesheet" href="[% uri_for('/static/css/blueprint/ie.css') %]" type="text/css" media="screen, projection"><![endif]--> 
    <link href="[% uri_for('/static/css/main.css') %]" rel="stylesheet" type="text/css" media="screen" />
    <script src="[% uri_for('/static/js/jquery-1.6.2.min.js') %]"></script>
    <!--[if lt IE 9]>
        <script src="http://html5shiv.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]-->
</head>
<body[% IF bodyID %] class="[% bodyID %]"[% END %]>
    <div class="container">
        <header>
            <a href="[% uri_for('/') %]"><% $module %></a>
        </header>
        <div id="main">
            [% content %]
        </div>
        <footer>
            Powered by <a href="http://amon.64p.org/">Amon2</a>
        </footer>
    </div>
</body>
</html>
...
	$self->write_file('static/javascript/' . Amon2::Setup::Asset::jQuery->jquery_min_basename(), Amon2::Setup::Asset::jQuery->jquery_min_content());
    $self->_cp(Amon2::Setup::Asset::BlueTrip->bluetrip_path, 'static/css');
    
    $self->write_file("t/00_compile.t", <<'...');
use strict;
use warnings;
use Test::More;

use_ok $_ for qw(
    <% $module %>
    <% $module %>::Web
    <% $module %>::Web::Dispatcher
);

done_testing;
...

    $self->write_file("xt/02_perlcritic.t", <<'...');
use strict;
use Test::More;
eval q{
	use Perl::Critic 1.113;
	use Test::Perl::Critic 1.02 -exclude => [
		'Subroutines::ProhibitSubroutinePrototypes',
		'Subroutines::ProhibitExplicitReturnUndef',
		'TestingAndDebugging::ProhibitNoStrict',
		'ControlStructures::ProhibitMutatingListFunctions',
	];
};
plan skip_all => "Test::Perl::Critic 1.02+ and Perl::Critic 1.113+ is not installed." if $@;
all_critic_ok('lib');
...

    $self->write_file('.gitignore', <<'...');
Makefile
inc/
MANIFEST
*.bak
*.old
nytprof.out
nytprof/
development.db
test.db
...

    for my $status (qw/404 500 502 503 504/) {
        $self->write_status_file("static/$status.html", $status);
    }
}

sub write_status_file {
    my ($self, $fname, $status) = @_;

    local $self->{status}         = $status;
    local $self->{status_message} = status_message($status);
 
    $self->write_file($fname, <<'...');
<!doctype html> 
<html> 
    <head> 
        <meta charset=utf-8 /> 
        <style type="text/css"> 
            body {
                text-align: center;
                font-family: 'Menlo', 'Monaco', Courier, monospace;
                background-color: whitesmoke;
                padding-top: 10%;
            }
            .number {
                font-size: 800%;
                font-weight: bold;
                margin-bottom: 40px;
            }
            .message {
                font-size: 400%;
            }
        </style> 
    </head> 
    <body> 
        <div class="number"><%= $status %></div> 
        <div class="message"><%= $status_message %></div> 
    </body> 
</html> 
...
}

sub _cp {
    my ($self, $from, $to) = @_;
    system("cp -Rp $from $to") == 0
        or die "external cp command status was $?";
}

1;


__END__

=head1 NAME

Amon2::Setup::Flavor::Rosiro -

=head1 SYNOPSIS

use Amon2::Setup::Flavor::Rosiro;

=head1 DESCRIPTION

Amon2::Setup::Flavor::Rosiro is

=head1 AUTHOR

Rosiro L<https://github.com/rosiro/>

=head1 SEE ALSO

L<https://github.com/rosiro/Amon2-Setup-Flavor-Rosiro>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
