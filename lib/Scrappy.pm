# ABSTRACT: All Powerful Web Spidering, Scrapering, Crawling Framework
# Dist::Zilla: +PodWeaver

package Scrappy;

# load OO System
use Moose;

# load other libraries
use Carp;
extends 'Scrappy::Scraper';

=head1 SYNOPSIS

    #!/usr/bin/perl
    use Scrappy;

    my  $scraper = Scrappy->new;
    
        $scraper->crawl('http://search.cpan.org/recent',
            '/recent' => {
                '#cpansearch li a' => sub {
                    print $_[1]->{href}, "\n";
                }
            }
        );
        
And now manually, ... without crawl, the above is similar to the following ...
    
    #!/usr/bin/perl
    use Scrappy;

    my $scraper = Scrappy->new;
    my $q       = $scraper->queue;
    
    $q->add('http://search.cpan.org/recent'); # starting url
    
    while (my $url = $q->next) {
        
        $scraper->get($url);
        
        foreach my $link (@{ $scraper->select('#cpansearch li a')->data }) {
            $q->add($link->href);
        }
    }

=head1 DESCRIPTION

Scrappy is an easy (and hopefully fun) way of scraping, spidering, and/or
harvesting information from web pages, web services, and more. Scrappy is a
feature rich, flexible, intelligent web automation tool.

Scrappy (pronounced Scrap+Pee) == 'Scraper Happy' or 'Happy Scraper'; If you
like you may call it Scrapy (pronounced Scrape+Pee) although Python has a web
scraping framework by that name and this module is not a port of that one.

=head2 FEATURES

Scrappy provides a framework containing all the tools neccessary to create a
simple yet powerful web scraper. At its core, Scrappy loads an array of
features for access control, event logging, session handling, url matching,
web request and response handling, proxy management, web scraping, and downloading.

Futhermore, Scrappy provides a simple Moose-based plugin system that allows Scrappy
to be easily extended.

    my  $scraper = Scrappy->new;
    
        $scraper->control;      # Scrappy::Scraper::Control (access control)
        $scraper->parser;       # Scrappy::Scraper::Parser (web scraper)
        $scraper->user_agent;   # Scrappy::Scraper::UserAgent (user-agent tools)
        $scraper->logger;       # Scrappy::Logger (event logger)
        $scraper->queue;        # Scrappy::Queue (flow control for loops)
        $scraper->session;      # Scrappy::Session (session management)

Please see the METHODS section for a more in-depth look at all Scrappy
functionality.

=cut

=head2 ATTRIBUTES

The following is a list of object attributes available with every Scrappy instance.

=head3 content

The content attribute holds the L<HTTP::Response> object of the current request.

    my  $scraper = Scrappy->new;
        $scraper->content;
        
=head3 control

The control attribute holds the L<Scrappy::Scraper::Control> object which is used
the provide access conrtol to the scraper.

    my  $scraper = Scrappy->new;
        $scraper->control;

=head3 debug

The debug attribute holds a boolean which controls whether event logs are captured.

    my  $scraper = Scrappy->new;
        $scraper->debug(1);
        
=head3 logger

The logger attribute holds the L<Scrappy::Logger> object which is used to provide
event logging capabilities to the scraper.

    my  $scraper = Scrappy->new;
        $scraper->logger;
        
=head3 parser

The parser attribute holds the L<Scrappy::Scraper::Parser> object which is used
to scrape html data from the specified source material.

    my  $scraper = Scrappy->new;
        $scraper->parser;
        
=head3 plugins

The plugins attribute holds the L<Scrappy::Plugin> object which is an interface
used to load plugins.

    my  $scraper = Scrappy->new;
        $scraper->plugins;
        
=head3 queue

The queue attribute holds the L<Scrappy::Queue> object which is used to provide
flow-control for the standard loop approach to crawling.

    my  $scraper = Scrappy->new;
        $scraper->queue;
        
=head3 session

The session attribute holds the L<Scrappy::Session> object which is used to provide
session support and persistent data across executions.

    my  $scraper = Scrappy->new;
        $scraper->session;
        
=head3 user_agent

The user_agent attribute holds the L<Scrappy::Scraper::UserAgent> object which is
used to set and manipulate the user-agent header of the scraper.

    my  $scraper = Scrappy->new;
        $scraper->user_agent;
        
=head3 worker

The worker attribute holds the L<WWW::Mechanize> object which is used navigate web
pages and provide request and response header information.

    my  $scraper = Scrappy->new;
        $scraper->worker;

=cut

=method back

The back method is the equivalent of hitting the "back" button in a browser, it
returns the previous page (response), it will not backtrack beyond the first request.

    my  $scraper = Scrappy->new;
        
        $scraper->get(...);
        ...
        $scraper->get(...);
        ...
        $scraper->back;

=cut

=method cookies

The cookies method returns an HTTP::Cookie object. Note! Cookies can be made
persistent by enabling session-support. Session-support is enable by simply
specifying a file to be used.

    my  $scraper = Scrappy->new;
    
        $scraper->session->write('session.yml'); # enable session support
        $scraper->get(...);
    my  $cookies = $scraper->cookies;

=cut

=method crawl

The crawl method is very useful when it is desired to crawl an entire website or
at-least partially, it automates the tasks of creating a queue, fetching and
parsing html pages, and establishing simple flow-control. See the SYNOPSIS for
a simplified example, ... the following is a more complex example.

    my  $scrappy = Scrappy->new;
    
        $scrappy->crawl('http://search.cpan.org/recent',
            '/recent' => {
                '#cpansearch li a' => sub {
                    my ($self, $item) = @_;
                    # follow all recent modules from search.cpan.org
                    $self->queue->add($item->{href});
                }
            },
            '/~:author/:name-:version/' => {
                'body' => sub {
                    my ($self, $item, $args) = @_;
                    
                    my $reviews = $self
                    ->select('.box table tr')->focus(3)->select('td.cell small a')
                    ->data->[0]->{text};
                    
                    $reviews = $reviews =~ /\d+ Reviews/ ?
                        $reviews : '0 reviews';
                    
                    print "found $args->{name} version $args->{version} ".
                        "[$reviews] by $args->{author}\n";
                }
            }
        );

=cut

sub crawl {
    my ($self, $starting_url, %pages) = @_;

    croak(
        'Please provide a starting URL and a valid configuration before crawling'
    ) unless ($self && $starting_url && keys %pages);

    # register the starting url
    $self->queue->add($starting_url);

    # start the crawl loop
    while (my $url = $self->queue->next) {

        # check if the url matches against any registered pages
        foreach my $page (keys %pages) {
            my $data = $self->page_match($page, $url);

            if ($data) {

                # found a page match, fetch and scrape the page for data
                $self->get($url);

                foreach my $selector (keys %{$pages{$page}}) {

                    # loop through resultset
                    foreach my $item (@{$self->select($selector)->data}) {

                        # execute selector code
                        $pages{$page}->{$selector}->($self, $item, $data);
                    }
                }
            }
        }
    }
}

=method domain

The domain method returns the domain host of the current page.

    my  $scraper = Scrappy->new;
    
        $scraper->get('http://www.google.com');
        print $scraper->domain; # print www.google.com

=cut

=method download

The download method is passed a URL, a Download Directory Path and a optionally
a File Path, then it will follow the link and store the response contents into
the specified file without leaving the current page. Basically it downloads the
contents of the request (especially when the request pushes a file download). If
a File Path is not specified, Scrappy will attempt to name the file automatically
resorting to a random 6-charater string only if all else fails, then returns to
the originating page.

    my  $scaper = Scrappy->new;
    my  $requested_url = '...';
    
        $scraper->download($requested_url, '/tmp');
    
        # supply your own file name
        $scraper->download($requested_url, '/tmp', 'somefile.txt');

=cut

=method form

The form method is used to submit a form on the current page.

    my  $scraper = Scrappy->new;
    
        $scraper->form(fields => {
            username => 'mrmagoo',
            password => 'foobarbaz'
        });
        
        # or more specifically, for pages with multiple forms
        
        $scraper->form(form_name => 'login_form', fields => {
            username => 'mrmagoo',
            password => 'foobarbaz'
        });
        
        $scraper->form(form_number => 1, fields => {
            username => 'mrmagoo',
            password => 'foobarbaz'
        });

=cut

=method get

The get method takes a URL or URI object, fetches a web page and returns an
HTTP::Response object.

    my  $scraper = Scrappy->new;
    my  $response = $scraper->get($new_url);

=cut

=method log

The log method logs an event with the event logger.

    my  $scraper = Scrappy->new;
        
        $scraper->debug(1); # unneccessary, on by default
        $scraper->logger->verbose(1); # more detailed log
        
        $scraper->log('error', 'Somthing bad happened');
        
        ...
        
        $scraper->log('info', 'Somthing happened');
        $scraper->log('warn', 'Somthing strange happened');
        $scraper->log('coolness', 'Somthing cool happened');
        
Note! Event logs are always recorded but never automatically written to a file
unless explicitly told to do so using the following:

        $scraper->logger->write('log.yml');

=cut

=method page_content_type

The page_content_type method returns the content_type of the current page.

    my  $scraper = Scrappy->new;
        $scraper->get('http://www.google.com/');
        print $scraper->page_content_type; # prints text/html

=cut

=method page_data

The page_data method returns the HTML content of the current page, additionally
this method when passed a string with HTML markup, updates the content of the
current page with that data and returns the modified content.

    my  $scraper = Scrappy->new;
        $scraper->get(...);
    my  $html = $scraper->page_data;

=cut

=method page_ishtml

The page_ishtml method returns true/false based on whether our content is HTML,
according to the HTTP headers.

    my $scraper = Scrappy->new;
    
        $scraper->get($requested_url);
        if ($scraper->is_html) {
            ...
        }

=cut

=method page_loaded

The page_loaded method returns true/false based on whether the last request was
successful.

    my $scraper = Scrappy->new;
    
        $scraper->get($requested_url);
        if ($scraper->page_loaded) {
            ...
        }

=cut

=method page_match

The page_match method checks the passed-in URL (or URL of the current page if
left empty) against the URL pattern (route) defined. If URL is a match, it will
return the parameters of that match much in the same way a modern web application
framework processes URL routes. 

    my $url = 'http://somesite.com/tags/awesomeness';
    
    ...
    
    my $scraper = Scrappy->new;
    
    # match against the current page
    my $this = $scraper->page_match('/tags/:tag');
    if ($this) {
        print $this->{'tag'};
        # ... prints awesomeness
    }
    
    .. or ..
    
    # match against a passed url
    my $this = $scraper->page_match('/tags/:tag', $url, {
        host => 'somesite.com'
    });
    
    if ($this) {
        print "This is the ", $this->{tag}, " page";
        # ... prints this is the awesomeness page
    }

=cut

=method page_reload

The page_reload method acts like the refresh button in a browser, it simply
repeats the current request.

    my  $scraper = Scrappy->new;
        
        $scraper->get(...);
        ...
        $scraper->reload;

=cut

=method page_status

The page_status method returns the 3-digit HTTP status code of the response.

    my  $scraper = Scrappy->new;
        $scraper->get(...);
        
        if ($scraper->page_status == 200) {
            ...
        }

=cut

=method page_text

The page_text method returns a text representation of the last page having
all HTML markup stripped.

    my  $scraper = Scrappy->new;
        $scraper->get(...);
        
    my  $text = $scraper->page_text;

=cut

=method page_title

The page_title method returns the content of the title tag if the current page
is HTML, otherwise returns undef.

    my  $scraper = Scrappy->new;
        $scraper->get('http://www.google.com/');
        
    my  $title = $scraper->page_title;
        print $title; # print Google

=cut

=method pause

This method sets breaks between your requests in an attempt to simulate human
interaction. 

    my  $scraper = Scrappy->new;
        $scraper->pause(20);
    
        $scraper->get($request_1);
        $scraper->get($request_2);
        $scraper->get($request_3);
    
Given the above example, there will be a 20 sencond break between each request made,
get, post, request, etc., You can also specify a range to have the pause method
select from at random...

        $scraper->pause(5,20);
    
        $scraper->get($request_1);
        $scraper->get($request_2);
    
        # reset/turn it off
        $scraper->pause(0);
    
        print "I slept for ", ($scraper->pause), " seconds";
    
Note! The download method is exempt from any automatic pausing.

=cut

=method plugin

The plugin method allow you to load a plugin. Using the appropriate case is
recommended but not neccessary. See L<Scrappy::Plugin> for more information.

    my $scraper = Scrappy->new;
    
    $scraper->plugin('foo_bar');    # will load Scrappy::Plugin::FooBar
    $scraper->plugin('foo-bar');    # will load Scrappy::Plugin::Foo::Bar
    $scraper->plugin('Foo::Bar');   # will load Scrappy::Plugin::Foo::Bar
    
    # more pratically
    $scraper->plugin('whois', 'spammer_check');
    
    ... somewhere in code
    
    my $var = $scraper->plugin_method();

    # example using core plugin Scrappy::Plugin::RandomProxy
    
    my  $s = Scrappy->new;
        
        $s->plugin('random_proxy');
        $s->use_random_proxy;
        
        $s->get(...);

=cut

=method post

The post method takes a URL, a hashref of key/value pairs, and optionally an
array of key/value pairs, and posts that data to the specified URL, then returns
an HTTP::Response object.

    my $scraper = Scrappy->new;

    $scraper->post($requested_url, {
        input_a => 'value_a',
        input_b => 'value_b'
    });
    
    # w/additional headers
    my %headers = ('Content-Type' => 'multipart/form-data');
    $scraper->post($requested_url, {
        input_a => 'value_a',
        input_b => 'value_b'
    },  %headers);

Note! The most common post headers for content-type are
application/x-www-form-urlencoded and multipart/form-data.

=cut

=method proxy

The proxy method will set the proxy for the next request to be tunneled through.

    my $scraper = Scrappy->new;
    
    $scraper->proxy('http', 'http://proxy1.example.com:8000/');
    $scraper->get($requested_url);
    
    $scraper->proxy('http', 'ftp', 'http://proxy2.example.com:8000/');
    $scraper->get($requested_url);
    
    # best practice when using proxies
    
    use Tiny::Try;
    
    my $proxie = Scrappy->new;
    
    $proxie->proxy('http', 'http://proxy.example.com:8000/');
    
    try {
        $proxie->get($requested_url);
    } catch {
        die "Proxy failed\n";
    };
    
Note! When using a proxy to perform requests, be aware that if they fail your
program will die unless you wrap your code in an eval statement or use a try/catch
mechanism. In the example above we use Tiny::Try to trap any errors that might occur
when using proxy.

=cut

=method request_denied

The request_denied method is a simple shortcut to determine if the page you
requested got loaded or redirected. This method is very useful on systems
that require authentication and redirect if not authorized. This function
return boolean, 1 if the current page doesn't match the requested page.

    my $scraper = Scrappy->new;
    $scraper->get($url_to_dashboard);
    
    if ($scraper->request_denied) {
        # do login, again
    }
    else {
        # resume ...
    }

=cut

=method response

The response method returns the HTTP::Repsonse object of the current page.

    my  $scraper = Scrappy->new;
        $scraper->get(...);
    my  $res = $scraper->response;

=cut

=method select

The select method takes XPATH or CSS selectors and returns an arrayref
with the matching elements.

    my $scraper = Scrappy->new;
    
    # return a list of links
    my $list = $scraper->select('#profile li a')->data; # see Scrappy::Scraper::Parser
    
    foreach my $link (@{$list}) {
        print $link->{href}, "\n";
    }
    
    # Zoom in on specific chunks of html code using the following ...
    my $list = $scraper
    ->select('#container table tr') # select all rows
    ->focus(4) # focus on the 5th row
    ->select('div div')->data;
    
    # The code above selects the div > div inside of the 5th tr in #container table
    # Access tag html, text and other attributes as follows...
    
    $element = $scraper->select('table')->data->[0];
    $element->{html}; # HTML representation of the table
    $element->{text}; # Table stripped of all HTML
    $element->{cellpadding}; # cellpadding
    $element->{height}; # ...
    
=cut

=method stash

The stash method sets a stash (shared) variable or returns a reference to the entire
stash object.

    my  $scraper = Scrappy->new;
        $scraper->stash(age => 31);
        
        print 'stash access works'
            if $scraper->stash('age') == $scraper->stash->{age};
    
    my  @array = (1..20);
        $scraper->stash(integers => [@array]);
    
=cut

=method store

The store method stores the contents of the current page into the specified file.
If the content-type does not begin with 'text', the content is saved as binary data.

    my  $scraper = Scrappy->new;
    
        $scraper->get($requested_url);
        $scraper->store('/tmp/foo.html');

=cut

=method url

The url method returns the complete URL for the current page.

    my  $scraper = Scrappy->new;
        $scraper->get('http://www.google.com/');
        print $scraper->url; # prints http://www.google.com/

=cut

1;
