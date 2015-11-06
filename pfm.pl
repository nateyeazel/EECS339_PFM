#!/usr/bin/perl -w

#
#
# pfm.pl (Red, White, and Blue)
#
#
# Example code for EECS 339, Northwestern University
#
# Peter Dinda
#
#
# Modified for Project 2
# Nicholas Hall, Nathan Yeazel, and Christopher Pierce
#
#

# The overall theory of operation of this script is as follows
#
# 1. The inputs are form parameters, if any, and a session cookie, if any.
# 2. The session cookie contains the login credentials (User/Password).
# 3. The parameters depend on the form, but all forms have the following three
#    special parameters:
#
#         act      =  form  <the form in question> (form=base if it doesn't exist)
#         run      =  0 Or 1 <whether to run the form or not> (=0 if it doesn't exist)
#         debug    =  0 Or 1 <whether to provide debugging output or not>
#
# 4. The script then generates relevant html based on act, run, and other
#    parameters that are form-dependent
# 5. The script also sends back a new session cookie (allowing for logout functionality)
# 6. The script also sends back a debug cookie (allowing debug behavior to propagate
#    to child fetches)
#


#
# Debugging
#
# database input and output is paired into the two arrays noted
#
my $debug=0; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;



#
# You need to override these for access to your database
#
my $dbuser="ndh242";
my $dbpasswd="zo06aFIky";


#
# The session cookie will contain the user's name and password so that
# he doesn't have to type it again and again.
#
# "PFMSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="PFMSession";
#
# And another cookie to preserve the debug state
#
my $debugcookiename="PFMDebug";

#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);
my $inputdebugcookiecontent = cookie($debugcookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $outputdebugcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $logincomplain=0;

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;


if (defined(param("act"))) {
    $action=param("act");
    if (defined(param("run"))) {
        $run = param("run") == 1;
    } else {
        $run = 0;
    }
} else {
    $action="base";
    $run = 1;
}

my $dstr;

if (defined(param("debug"))) {
    # parameter has priority over cookie
    if (param("debug") == 0) {
        $debug = 0;
    } else {
        $debug = 1;
    }
} else {
    if (defined($inputdebugcookiecontent)) {
        $debug = $inputdebugcookiecontent;
    } else {
        # debug default from script
    }
}

$outputdebugcookiecontent=$debug;

#
#
# Who is this?  Use the cookie or anonymous credentials
#
#
if (defined($inputcookiecontent)) {
    # Has cookie, let's decode it
    ($user,$password) = split(/\//,$inputcookiecontent);
    $outputcookiecontent = $inputcookiecontent;
} else {
    # No cookie, direct to login page
    $action="login";
    $run = 0;
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") {
    if ($run) {
        #
        # Login attempt
        #
        # Ignore any input cookie.  Just validate user and
        # generate the right output cookie, if any.
        #
        ($user,$password) = (param('user'),param('password'));
        if (ValidUser($user,$password)) {
            # if the user's info is OK, then give him a cookie
            # that contains his username and password
            # the cookie will expire in one hour, forcing him to log in again
            # after one hour of inactivity.
            # Also, land him in the base query screen
            $outputcookiecontent=join("/",$user,$password);
            $action = "base";
            $run = 1;
        } else {
            # uh oh.  Bogus login attempt.  Make him try again.
            # don't give him a cookie
            $logincomplain=1;
            $action="login";
            $run = 0;
        }
    } else {
        #
        # Just a login screen request, but we should toss out any cookie
        # we were given
        #
        undef $inputcookiecontent;
    }
}


#
# If we are being asked to log out, then if
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
    $deletecookie=1;
    $action = "base";
    $user = "anon";
    $password = "anonanon";
    $run = 1;
}


my @outputcookies;

#
# OK, so now we have user/password
# and we *may* have an output cookie.   If we have a cookie, we'll send it right
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) {
    my $cookie=cookie(-name=>$cookiename,
    -value=>$outputcookiecontent,
    -expires=>($deletecookie ? '-1h' : '+1h'));
    push @outputcookies, $cookie;
}
#
# We also send back a debug cookie
#
#
if (defined($outputdebugcookiecontent)) {
    my $cookie=cookie(-name=>$debugcookiename,
    -value=>$outputdebugcookiecontent);
    push @outputcookies, $cookie;
}

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
#print start_html('Portforlio Manager 2K15');
print "<html style=\"height: 100\%\">";
print "<head>";
print "<title>Portforlio Manager 2K15</title>";
print "</head>";

print "<body style=\"height:100\%;margin:0\">";

#
# Force device width, for mobile phones, etc
#
#print "<meta name=\"viewport\" content=\"width=device-width\" />\n";

# This tells the web browser to render the page in the style
# defined in the css file
#
print "<style type=\"text/css\">\n\@import \"pfm.css\";\n</style>\n";


print "<center>" if !$debug;


#
#
# The remainder here is essentially a giant switch statement based
# on $action.
#
#
#


# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code.  So, here we only show the form if needed
#
#
if ($action eq "login") {
    if ($logincomplain) {
        print "Login failed.  Try again.<p>"
    }
    if ($logincomplain or !$run) {
        print start_form(-name=>'Login'),
        h2('Login to Portfolio Manager 2K15'),
        "Name:",textfield(-name=>'user'), p,
        "Password:",password_field(-name=>'password'),p,
        hidden(-name=>'act',default=>['login']),
        hidden(-name=>'run',default=>['1']),
        submit,
        end_form;
    }
}



#
# BASE
#
# The base action presents the overall page to the browser
# This is the "document" that the JavaScript manipulates
#
#
if ($action eq "base") {
    #
    # And a div to populate with info about nearby stuff
    #
    #
    if ($debug) {
        # visible if we are debugging
        print "<div id=\"data\" style=\:width:100\%; height:10\%\"></div>";
    } else {
        # invisible otherwise
        print "<div id=\"data\" style=\"display: none;\"></div>";
    }
    
    
    # height=1024 width=1024 id=\"info\" name=\"info\" onload=\"UpdateMap()\"></iframe>";
    
    
    #
    # User mods
    #
    #
    print "<p>You are logged in as $user and can do the following:</p>";
    print "<p><a href=\"pfm.pl?act=logout&run=1\">Logout</a></p>";
    
}

#
# ADD-USER
#
# User Add functionaltiy
#
#
#
#
if ($action eq "add-user") {
    if (!UserCan($user,"add-users") && !UserCan($user,"manage-users")) {
        print h2('You do not have the required permissions to add users.');
    } else {
        if (!$run) {
            print start_form(-name=>'AddUser'),
            h2('Add User'),
            "Name: ", textfield(-name=>'name'),
            p,
            "Email: ", textfield(-name=>'email'),
            p,
            "Password: ", textfield(-name=>'password'),
            p,
            hidden(-name=>'run',-default=>['1']),
            hidden(-name=>'act',-default=>['add-user']),
            submit,
            end_form,
            hr;
        } else {
            my $name=param('name');
            my $email=param('email');
            my $password=param('password');
            my $error;
            $error=UserAdd($name,$password,$email,$user);
            if ($error) {
                print "Can't add user because: $error";
            } else {
                print "Added user $name $email as referred by $user\n";
            }
        }
    }
    print "<p><a href=\"pfm.pl?act=base&run=1\">Return</a></p>";
}

#
# REGISTER-USER
#
# Register User functionaltiy
#
#
#
#
if ($action eq "register-user") {
    my $id = param("id");
    my @invites = eval { ExecSQL($dbuser,$dbpasswd,
        "select email, referer from pfm_invites where id=?",undef,$id);
    };
    my $invite_info = $invites[0];
    my $email = @{$invite_info}[0];
    my $referer = @{$invite_info}[1];
    
    if (!$run) {
        print start_form(-name=>'RegisterUser'),
        h2('Register User'),
        "Email: ", textfield(-name=>'email',-default =>$email),
        p,
        "Username: ", textfield(-name=>'username'),
        p,
        "Password: ", textfield(-name=>'password'),
        p,
        hidden(-name=>'run',-default=>['1']),
        hidden(-name=>'id',-default=>[$id]),
        hidden(-name=>'referer',-default=>[$referer]),
        hidden(-name=>'act',-default=>['register-user']),
        submit,
        end_form,
        hr;
    } else {
        my $username=param('username');
        my $password=param('password');
        my $email=param('email');
        my $referer=param('referer');
        my $error=UserAdd($username, $password, $email, $referer);
        if ($error) {
            print "Can't register user because: $error";
        } else {
            print "Registered user $email\n";
        }
    }
    print "<p><a href=\"pfm.pl?act=base&run=1\">Return</a></p>";
}


#
#
#
#
# Debugging output is the last thing we show, if it is set
#
#
#
#

print "</center>" if !$debug;

#
# Generate debugging output if anything is enabled.
#
#
if ($debug) {
    print hr, p, hr,p, h2('Debugging Output');
    print h3('Parameters');
    print "<menu>";
    print map { "<li>$_ => ".escapeHTML(param($_)) } param();
    print "</menu>";
    print h3('Cookies');
    print "<menu>";
    print map { "<li>$_ => ".escapeHTML(cookie($_))} cookie();
    print "</menu>";
    my $max= $#sqlinput>$#sqloutput ? $#sqlinput : $#sqloutput;
    print h3('SQL');
    print "<menu>";
    for (my $i=0;$i<=$max;$i++) {
        print "<li><b>Input:</b> ".escapeHTML($sqlinput[$i]);
        print "<li><b>Output:</b> $sqloutput[$i]";
    }
    print "</menu>";
}

print end_html;

#
# The main line is finished at this point.
# The remainder includes utilty and other functions
#

#
# Add a user
# call with name,password,email
#
# returns false on success, error string on failure.
#
# UserAdd($name,$password,$email)
#
sub UserAdd {
    eval { ExecSQL($dbuser,$dbpasswd,
        "insert into pfm_users (name,password,email,referer) values (?,?,?,?)",undef,@_);};
    return $@;
}

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
    my ($user,$password)=@_;
    my @col;
    eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from pfm_users where name=? and password=?","COL",$user,$password);};
    if ($@) {
        return 0;
    } else {
        return $col[0]>0;
    }
}


#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
    my ($id,$type,$headerlistref,@list)=@_;
    my $out;
    #
    # Check to see if there is anything to output
    #
    if ((defined $headerlistref) || ($#list>=0)) {
        # if there is, begin a table
        #
        $out="<table id=\"$id\" border>";
        #
        # if there is a header list, then output it in bold
        #
        if (defined $headerlistref) {
            $out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
        }
        #
        # If it's a single row, just output it in an obvious way
        #
        if ($type eq "ROW") {
            #
            # map {code} @list means "apply this code to every member of the list
            # and return the modified list.  $_ is the current list member
            #
            $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
        } elsif ($type eq "COL") {
            #
            # ditto for a single column
            #
            $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
        } else {
            #
            # For a 2D table, it's a bit more complicated...
            #
            $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
        }
        $out.="</table>";
    } else {
        # if no header row or list, then just say none.
        $out.="(none)";
    }
    return $out;
}


#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
    my ($id, $type,@list)=@_;
    my $out;
    #
    # Check to see if there is anything to output
    #
    $out="<pre id=\"$id\">\n";
    #
    # If it's a single row, just output it in an obvious way
    #
    if ($type eq "ROW") {
        #
        # map {code} @list means "apply this code to every member of the list
        # and return the modified list.  $_ is the current list member
        #
        $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
        $out.="\n";
    } elsif ($type eq "COL") {
        #
        # ditto for a single column
        #
        $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
        $out.="\n";
    } else {
        #
        # For a 2D table
        #
        foreach my $r (@list) {
            $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
            $out.="\n";
        }
    }
    $out.="</pre>\n";
    return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
    my ($user, $passwd, $querystring, $type, @fill) =@_;
    if ($debug) {
        # if we are recording inputs, just push the query string and fill list onto the
        # global sqlinput list
        push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
    }
    my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
    if (not $dbh) {
        # if the connect failed, record the reason to the sqloutput list (if set)
        # and then die.
        if ($debug) {
            push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
        }
        die "Can't connect to database because of ".$DBI::errstr;
    }
    my $sth = $dbh->prepare($querystring);
    if (not $sth) {
        #
        # If prepare failed, then record reason to sqloutput and then die
        #
        if ($debug) {
            push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
        }
        my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
        $dbh->disconnect();
        die $errstr;
    }
    if (not $sth->execute(@fill)) {
        #
        # if exec failed, record to sqlout and die.
        if ($debug) {
            push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
        }
        my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
        $dbh->disconnect();
        die $errstr;
    }
    #
    # The rest assumes that the data will be forthcoming.
    #
    #
    my @data;
    if (defined $type and $type eq "ROW") {
        @data=$sth->fetchrow_array();
        $sth->finish();
        if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
        $dbh->disconnect();
        return @data;
    }
    my @ret;
    while (@data=$sth->fetchrow_array()) {
        push @ret, [@data];
    }
    if (defined $type and $type eq "COL") {
        @data = map {$_->[0]} @ret;
        $sth->finish();
        if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
        $dbh->disconnect();
        return @data;
    }
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
    $dbh->disconnect();
    return @ret;
}


######################################################################
#
# Nothing important after this
#
######################################################################

# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
    unless ($ENV{BEGIN_BLOCK}) {
        use Cwd;
        $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
        $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
        $ENV{ORACLE_SID}="CS339";
        $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
        $ENV{BEGIN_BLOCK} = 1;
        exec 'env',cwd().'/'.$0,@ARGV;
    }
}

