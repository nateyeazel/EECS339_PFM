#!/usr/bin/perl -w

#
#
# pfm.pl (Portfolio Manager 2K15)
#
#
# Adapted from rwb.pl example code for EECS 339, Northwestern University
#
# Peter Dinda
#
#
# Modified for Project 2
#
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

if (($action eq "portfolio" or $action eq "deposit-withdraw" or $action eq "buy-sell" or $action eq "record-prics") and (!defined(param("pname")) or param("pname") eq '')) {
    $action = "base";
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
# Who is this?  Use the cookie or send to login page
#
#
if (defined($inputcookiecontent)) {
    # Has cookie, let's decode it
    ($user,$password) = split(/\//,$inputcookiecontent);
    $outputcookiecontent = $inputcookiecontent;
} else {
    # No cookie, direct to login page
    $action="login";
    if (!defined(param("user"))){
        $run=0;
    }
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
        if (NewUser($user)) {
            my $error=UserAdd($user,$password);
            if ($error) {
                $logincomplain=2;
                $action="login";
                $run = 0;
            }
        }
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
    $action = "login";
    $run = 0;
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
#print start_html('Portfolio Manager 2K15');
print "<html style=\"height: 100\%\">";
print "<head>";
print "<title>Portfolio Manager 2K15</title>";
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


print "<center>";


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
    if ($logincomplain or !$run) {
        print start_form(-name=>'Login'),
        h2('Sign in to Portfolio Manager 2K15'),
        "Name ",textfield(-name=>'user'), p,
        "Password ",password_field(-name=>'password'),p,
        hidden(-name=>'act',default=>['login']),
        hidden(-name=>'run',default=>['1']),
        submit,
        end_form;
    }
    if ($logincomplain) {
        print "Invalid username/password combination.<p>"
    }
}

if ($action ne "login") {

    # Header
    print h2('Portfolio Manager 2K15'),
    "Welcome, $user\!\t",
    "<a href=\"pfm.pl?act=logout&run=1\">Log Out</a></p>",
    hr;
}


#
# BASE
#
# The base action presents the overall page to the browser
# This is the "document" that the JavaScript manipulates
#
#
if ($action eq "base") {

    # Portfolios Table
    my $format = param("format");
    $format = "linked-table" if !defined($format);
    my ($str,$error) = Portfolios($format);
    if (!$error) {
        if ($format eq "linked-table") {
            print "<h3>Portfolios</h3>$str";
        } else {
            print $str;
        }
    }
    print "</p><a href=\"pfm.pl?act=create-portfolio\">Create New Portfolio</a></p>";

    if ($debug) {
        # visible if we are debugging
        print "<div id=\"data\" style=\:width:100\%; height:10\%\"></div>";
    } else {
        # invisible otherwise
        print "<div id=\"data\" style=\"display: none;\"></div>";
    }
}

#
# The main line is finished at this point.
# The remainder includes utilty and other functions
#

if ($action eq "create-portfolio") {
    if (!$run) {
        #
        # Generate the invite form.
        #
        print start_form(-name=>'CreatePortfolio'),
        h2('Create New Portfolio'),
        "Portfolio Name ", textfield(-name=>'portfolio-name'),
        p,
        hidden(-name=>'run',-default=>['1']),
        hidden(-name=>'act',-default=>['create-portfolio']),
        submit,
        end_form;
    } else {
        my $name=param('portfolio-name');
        my $error=PortfolioAdd($name);
        if ($error) {
            print "Couldn't create portfolio because: $error";
        } else {
            print "Created portfolio $name\.\n";
        }
    }
    print hr,
    "<p><a href=\"pfm.pl?act=base&run=1\">Return</a></p>";
}

if ($action eq "portfolio") {
    my $pname = param("pname");
    my $pid = PortfolioID($pname);

    # Portfolio Holdings Table
    my $format = param("format");
    $format = "linked-table" if !defined($format);
    my ($str,$error) = PortfolioHoldings($pname, $pid, $format);
    if (!$error) {
        if ($format eq "linked-table") {
            print "<h3>$pname Portfolio</h3>$str";
        } else {
            print $str;
        }
    }
    
    my $totalvalue = TotalValue($pid);
    my $totalcash = CashBalance("number",$pid);
    if ($totalvalue <= 0) {
        $totalvalue = 0;
    }
    my $total = $totalvalue+$totalcash;
    print p,
        "<table id=\"totals\" border=\"\"><tbody><tr><td><b>Total Value of Stocks</b></td><td>$totalvalue</td></tr><tr><td><b>Cash Balance</b></td><td>$totalcash</td></tr><tr><td><b>Total Value of Portfolio</b></td><td>$total</td></tr></tbody></table>";

    print "</p><a href=\"pfm.pl?act=deposit-withdraw&pname=$pname\">Deposit/Withdraw Cash</a></p>";
    print "</p><a href=\"pfm.pl?act=buy-sell&pname=$pname\">Buy/Sell Stock</a></p>";
    print "</p><a href=\"pfm.pl?act=record-price&pname=$pname\">Record Stock Price</a></p>";
    print "</p><a href='pfm.pl?act=covar-matrix&pname=$pname'>See Covariance Matrix</a></p>";

    print hr,
    "<p><a href=\"pfm.pl?act=base&run=1\">Return</a></p>";
}

if($action eq "covar-matrix") {
    my $pname = param("pname");
    my $pid = PortfolioID($pname);

    print "<h3>Covariance Matrix</h3>";
    print "Select a date and time:", p;
    print start_form(-name=>'Record new data', -method =>'POST'),
        "Start ",
        "<input name = 'start' type='date'>",
        p,
        "End ",
        "<input name = 'end' type='date'>",
        hidden(-name=>'run',-default=>['1']),
        hidden(-name=>'act',-default=>['portfolio']),
        hidden(-name=>'pname',-default=>['$pname']),
        p,
        submit(-name=> 'select-covar-dates', -value=>'Select Date Range'),
        end_form;

    if(!$run){
        
    } elsif(param('select-covar-dates')){
        my $symbols = PortolioSymbols($pid);
        my $symbolsString = '';
        my $start = param('start');
        my $end = param('end');
        while ($symbols =~ /(\w+)\n/g){
            $symbolsString .= $1;
            $symbolsString .= ' ';
        }
        my $results = `./get_covar.pl --field1=close --field2=close --from=$start --to=$end $symbolsString`;
        print "<pre>", $results, "</pre>"; 
    }
    
    print hr,
    "<p><a href=\"pfm.pl?act=portfolio&pname=$pname\">Return</a></p>";
}

if ($action eq "deposit-withdraw") {
    my $pname = param("pname");
    my $pid = PortfolioID($pname);
    my $format = param("format");
    $format = "table" if !defined($format);

    if (!$run) {
        # Cash Balance
        my ($str,$error) = CashBalance($format,$pid);
        print h3('Deposit/Withdraw Stock'), p;
        if (!$error) {
            print $str;
        }
        print start_form(-name=>'DepositWithdraw', -method=>'POST'),
            "Amount ",
            textfield(-name=>'amount'),
            p,
            hidden(-name=>'run',-default=>['1']),
            hidden(-name=>'act',-default=>['deposit-withdraw']),
            hidden(-name=>'pname',-default=>['$pname']),
            submit(-name => 'deposit', -value => 'Deposit'),
            submit(-name => 'withdraw', -value => 'Withdraw'),
            end_form;
    } elsif (param('deposit')) {
        my $amount=param('amount');
        my $error1=CashDeposit($pid, $amount);
        # Cash Balance
        my ($str,$error) = CashBalance($format,$pid);
        print h3('Deposit/Withdraw'), p;
        if (!$error) {
            print $str;
        }
        if ($error1) {
            print p, "Error: Couldn't deposit \$$amount\ into account.";
        } else {
            print p, "Deposited \$$amount\ into cash account.\n";
        }
    } elsif (param('withdraw')) {
        my $amount=param('amount');
        my $error2=CashWithdraw($pid, $amount);
        # Cash Balance
        my ($str,$error) = CashBalance($format,$pid);
        print h3('Deposit/Withdraw'), p;
        if (!$error) {
            print $str;
        }
        if ($error2) {
            print p, "Error: Couldn't withdraw \$$amount\ from account.";
        } else {
            print p, "Withdrew \$$amount\ from cash account.\n";
        }

    }

    print hr,
    "<p><a href=\"pfm.pl?act=portfolio&pname=$pname\">Return</a></p>";
}

#For when you buy and sell stocks
if($action eq "buy-sell"){
    my $pname = param("pname");
    my $pid = PortfolioID($pname);
    my $format = param("format");

    $format = "table" if !defined($format);

    if (!$run) {
        # Portfolio Holdings Table
        my ($str,$error) = PortfolioHoldings($pname, $pid, "table");
        print h3('Buy/Sell Stock'), p;
        if (!$error) {
            print "$str";
        }
        print p;
        
        # Cash Balance
        my $totalcash = CashBalance("number",$pid);
        print "<table id=\"cash-balance\" border=\"\"><tbody><tr><td><b>Cash Balance</b></td><td>$totalcash</td></tr></tbody></table>";
        print start_form(-name=>'Buy Stocks', -method=>'POST'),
            p,
            "Symbol ",
            textfield(-name=>'stock-symbol'),
            p,
            "Amount ",
            textfield(-name=> 'stocks-amount'),
            hidden(-name=>'run',-default=>['1']),
            hidden(-name=>'act',-default=>['buy-sell']),
            hidden(-name=>'pname',-default=>['$pname']),
            p,
            submit(-name => 'buy', -value => 'Buy'),
            submit(-name => 'sell', -value => 'Sell'),
            end_form;
    } elsif(param('buy')){
        my $symb = param('stock-symbol');
        my $amount = param('stocks-amount');
        my $stockPrice = getRecentPrice($symb);
        my $cash_balance = CashBalance('number', $pid);
        my $cost = $stockPrice * $amount;
        if($cost <= 0){
            # Portfolio Holdings Table
            my ($str,$error) = PortfolioHoldings($pname, $pid, "table");
            print h3('Buy/Sell Stock'), p;
            if (!$error) {
                print "$str";
            }
            print p;
            
            # Cash Balance
            my $totalcash = CashBalance("number",$pid);
            print "<table id=\"cash-balance\" border=\"\"><tbody><tr><td><b>Cash Balance</b></td><td>$totalcash</td></tr></tbody></table>";
            print p, "Error: Invalid purchase.";
        } elsif ($cost > $cash_balance){
            # Portfolio Holdings Table
            my ($str,$error) = PortfolioHoldings($pname, $pid, "table");
            print h3('Buy/Sell Stock'), p;
            if (!$error) {
                print "$str";
            }
            print p;
            
            # Cash Balance
            my $totalcash = CashBalance("number",$pid);
            print "<table id=\"cash-balance\" border=\"\"><tbody><tr><td><b>Cash Balance</b></td><td>$totalcash</td></tr></tbody></table>";
            print p, "Error: Insufficient funds to purchase $amount shares of $symb at \$$stockPrice\/share with a cash balance of \$$cash_balance\.";
        } else {
            my $error1 = CashWithdraw($pid, $amount * $stockPrice);
            my $error2 = BuyStock($amount, $symb, $pid);
            # Portfolio Holdings Table
            my ($str,$error) = PortfolioHoldings($pname, $pid, "table");
            print h3('Buy/Sell Stock'), p;
            if (!$error) {
                print "$str";
            }
            print p;
            
            # Cash Balance
            my $totalcash = CashBalance("number",$pid);
            print "<table id=\"cash-balance\" border=\"\"><tbody><tr><td><b>Cash Balance</b></td><td>$totalcash</td></tr></tbody></table>";
            if ($error2)
            {
                print p, "Error: Purchase failed.";
            } else {
                print p, "Successfully purchased $amount shares of $symb for \$$cost\.";
            }
        }

    } elsif(param('sell')){
        my $symb = param('stock-symbol');
        my $amount = param('stocks-amount');
        my $stockPrice = getRecentPrice($symb);
        my $cost = $stockPrice * $amount;
        if ($cost <= 0) {
            # Portfolio Holdings Table
            my ($str,$error) = PortfolioHoldings($pname, $pid, "table");
            print h3('Buy/Sell Stock'), p;
            if (!$error) {
                print "$str";
            }
            print p;
            
            # Cash Balance
            my $totalcash = CashBalance("number",$pid);
            print "<table id=\"cash-balance\" border=\"\"><tbody><tr><td><b>Cash Balance</b></td><td>$totalcash</td></tr></tbody></table>";
            print p, "Error: Invalid sale.";
        } else {
            my $error2 = SellStock($amount, $symb, $pid);
            # Portfolio Holdings Table
            my ($str,$error) = PortfolioHoldings($pname, $pid, "table");
            print h3('Buy/Sell Stock'), p;
            if (!$error) {
                print "$str";
            }
            print p;
            
            # Cash Balance
            my $totalcash = CashBalance("number",$pid);
            print "<table id=\"cash-balance\" border=\"\"><tbody><tr><td><b>Cash Balance</b></td><td>$totalcash</td></tr></tbody></table>";
            if ($error2)
            {
                print p, "Error: Sale failed.";
            } else {
                my $error1 = CashDeposit($pid, $amount * $stockPrice);
                print p, "Successfully sold $amount shares of $symb for \$$cost\.";
            }
        }
    }

    print hr,
        "<p><a href=\"pfm.pl?act=portfolio&pname=$pname\">Return</a></p>";
}

if ($action eq "record-price"){
    my $pname= param("pname");
    my $pid = PortfolioID($pname);
    my $format = param("format");
    $format = "table" if !defined($format);

    if (!$run){
        print start_form(-name=>'Record new data', -method =>'POST'),
        h3('Record Stock Price'),
        "Symbol ",
        textfield(-name=>'stock-symbol'),
        p,
        "High ",
        textfield(-name=>'high-price'),
        p,
        "Low ",
        textfield(-name=>'low-price'),
        p,
        "Close ",
        textfield(-name=>'close-price'),
        p,
        "Open ",
        textfield(-name=>'open-price'),
        p,
        "Volume ",
        textfield(-name=>'volume-traded'),
        hidden(-name=>'run',-default=>['1']),
        hidden(-name=>'act',-default=>['record-price']),
        hidden(-name=>'pname',-default=>['$pname']),
        p,
        submit(-name=> 'add-record', -value=>'Submit Record'),
        end_form;
    }
    elsif(param('add-record')){
        my $symb= param('stock-symbol');
        my $high= param('high-price');
        my $low= param('low-price');
        my $close = param('close-price');
        my $open = param('open-price');
        my $volume= param('volume-traded');
        my $error= RecordPrice($symb, $high, $low, $close, $open, $volume);
        if ($error){
            print "Error: Couldn't add record.";
        }
        else {
            print "Record added successfully.";
        }
    }
    
    print hr,
        "<p><a href=\"pfm.pl?act=portfolio&pname=$pname\">Return</a></p>";
}

if ($action eq 'stock'){
    my $pname = param("pname");
    my $pid = PortfolioID($pname);
    my $format = param("format");
    $format = "table" if !defined($format);

    my $symbol = param("symbol");
    my $cash = CashBalance('number', $pid);
    my $recentPrice = getRecentPrice($symbol);

    $format = "table" if !defined($format);

    if (!$run){
    print "<h2>Stock Information for $symbol</h2>";
    print "<img src='http://murphy.wot.eecs.northwestern.edu/~ndh242/pfm/plot_stock.pl?type=plot&symbol=$symbol'>";
    print "<h3>Select date range for past data</h3>";
    print start_form(-name=>'Select data dates', -method =>'POST'),
        "Start date:",
        "<input name = 'start' type='date'>",
        p,
        "End Date:",
        "<input name = 'end' type='date'>",
        hidden(-name=>'run',-default=>['1']),
        hidden(-name=>'act',-default=>['stock']),
        hidden(-name=>'pname',-default=>['$pname']),
        p,
        submit(-name=> 'select-dates', -value=>'Select Date Range'),
        end_form;
    }
    elsif(param('select-dates')){
      my $start = param('start');
      my $end = param('end');
      my $output = `./get_data.pl --close --from="$start" --to="$end" AAPL`;
      #my $image = `./get_data.pl --close --from="$start" --to="$end" --plot AAPL`;
      #print "<pre>", $image, "</pre>";
      #print "<img src='http:/murphy.wot.eecs.northwestern.edu/~ndh242/pfm/plot_stock.pl&type=plot&symbol=AAPL'>"; 
      print "Timestamp      Close Price";
      print "<pre>", $output, "</pre>";  
    }  

    print "<h3>Automated Trading Strategy Predictions for $symbol</h3>";
    my $predictionResult = `./shannon_ratchet.pl $symbol $cash $recentPrice`;
    print "<pre>", $predictionResult, "</pre>";

    print hr,
        "<p><a href=\"pfm.pl?act=portfolio&pname=$pname\">Return</a></p>";
}

sub RecordPrice{
    my ($symb, $high, $low, $close, $open, $volume) = @_;
    my @rows;
    my $date= time();
    eval{
        @rows= ExecSQL($dbuser, $dbpasswd, "insert into pfm_stocksData(symbol, timestamp, high, low, close, open, volume) values (?, ?, ?, ?, ?, ?, ?)", undef, $symb, $date, $high, $low, $close, $open, $volume);
    };
    return $@;
}
print "</center>";

if ($debug) {
    print hr, p, h2('Debugging Output');
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


sub PortfolioID {
    my ($pname) = @_;
    my @rows;
    eval {
        @rows = ExecSQL($dbuser, $dbpasswd, "select portfolio_id from pfm_portfolios where user_id=? and portfolio_name=?",undef,$user,$pname);
    };
    if ($@) {
        return (undef,$@);
    } else {
        foreach my $row (@rows)
        {
            return @$row[0];
        }
    }
}

sub Portfolios {
    my ($format) = @_;
    my @rows;
    eval {
        @rows = ExecSQL($dbuser, $dbpasswd, "select portfolio_name from pfm_portfolios where user_id=?",undef,$user);
    };
    if ($@) {
        return (undef,$@);
    } else {
        if ($format eq "linked-table") {
            return (MakeLinkedTable("portfolios_list","2D",
            ["Portfolios"],"portfolio&pname=",
            @rows),$@);
        } elsif ($format eq "table") {
            return (MakeTable("portfolios_list","2D",
            ["Portfolios"],
            @rows),$@);
        } else {
            return (MakeRaw("portfolios_list","2D",@rows),$@);
        }
    }
}

sub PortfolioHoldings {
    my ($pname, $pid, $format) = @_;
    my @rows;
    eval {
        @rows = ExecSQL($dbuser, $dbpasswd, "select t1.symbol, num_shares, close, num_shares * close from (select symbol, num_shares from pfm_portfolioHoldings where portfolio_id = ?) t1 join (select symbol, close from allStockData where (symbol, timestamp) in (select symbol, max(timestamp) as timestamp from (select * from cs339.StocksDaily where symbol in (select symbol from pfm_portfolioHoldings where portfolio_id = ?) union select * from pfm_stocksData where symbol in (select symbol from pfm_portfolioHoldings where portfolio_id = ?)) group by symbol)) t2 on t1.symbol=t2.symbol",undef,$pid,$pid,$pid);
    };
    if ($@) {
        return (undef,$@);
    } else {
        if ($format eq "linked-table") {
            return (MakeLinkedTable("portfolio_holdings","2D",
            ["Stock", "Shares", "Price", "Value"],"stock&pname=$pname&symbol=",
            @rows),$@);
        } elsif ($format eq "table") {
            return (MakeTable("portfolio_holdings","2D",
            ["Stock", "Shares", "Price", "Value"],
            @rows),$@);
        } else {
            return (MakeRaw("portfolio_holdings","2D",@rows),$@);
        }
    }
}

sub PortolioSymbols {
    my($pid) = @_;
    my @rows;

    eval{
        @rows = ExecSQL($dbuser, $dbpasswd, "select symbol from pfm_portfolioHoldings where portfolio_id=?",undef,$pid);
    };
    return (MakeRaw("portfolio_symbols", '2D', @rows));
}

sub CashDeposit {
    my ($pid, $amount) = @_;
    my @errors;
    eval { @errors = ExecSQL($dbuser, $dbpasswd, "update pfm_portfolios set cash = cash + ? where portfolio_id=?",undef,$amount,$pid);
    };
    if ($@) {
        return (undef,$@);
    } else {
        return @;
    }
}

sub CashWithdraw {
    my ($pid, $amount) = @_;
    my @errors;
    eval { @errors = ExecSQL($dbuser, $dbpasswd, "update pfm_portfolios set cash = cash - ? where portfolio_id=?",undef,$amount,$pid);
    };
    if ($@) {
        return (undef,$@);
    } else {
        return @;
    }
}

sub CashBalance {
    my ($format, $pid) = @_;
    my @rows;
    eval {
        @rows = ExecSQL($dbuser, $dbpasswd, "select cash from pfm_portfolios where portfolio_id=?",undef,$pid);
    };
    if ($@) {
        return (undef,$@);
    } else {
        if ($format eq "table") {
            return (MakeTable("cash_balance","2D",
            ["Current Cash Balance"],
            @rows),$@);
        } elsif ($format eq 'number') {
            foreach my $row (@rows)
            {
                return @$row[0];
            }
        }
    }
}

sub TotalValue {
    my ($pid) = @_;
    my @rows;
    eval {
        @rows = ExecSQL($dbuser, $dbpasswd, "select sum(num_shares * close) from (select symbol, num_shares from pfm_portfolioHoldings where portfolio_id = ?) t1 join (select symbol, close from allStockData where (symbol, timestamp) in (select symbol, max(timestamp) as timestamp from (select * from cs339.StocksDaily where symbol in (select symbol from pfm_portfolioHoldings where portfolio_id = ?) union select * from pfm_stocksData where symbol in (select symbol from pfm_portfolioHoldings where portfolio_id = ?)) group by symbol)) t2 on t1.symbol=t2.symbol",undef,$pid,$pid,$pid);
    };
    if ($@) {
        return (undef,$@);
    } else {
        foreach my $row (@rows)
        {
            return @$row[0];
        }
    }
}

sub getRecentPrice {
    my($symb) = @_;
    my @rows;
    eval{
        @rows = ExecSQL($dbuser, $dbpasswd, "select close from allStockData where symbol = ? and timestamp= (select max(timestamp) from allStockData where symbol = ?)", undef, $symb, $symb);
    };
    if($@) {
        return (undef, $@);
    } else {
        foreach my $row (@rows)
        {
            return @$row[0];
        }
    }
}

sub BuyStock {
    my($amount, $symb, $pid) = @_;
    my $currentTime = time();
    my @rows;
    my $price = getRecentPrice($symb);
    eval{
        @rows = ExecSQL($dbuser, $dbpasswd, "select num_shares from pfm_portfolioHoldings where portfolio_id = ? and symbol = ?", undef, $pid, $symb)
    };
    if ($@) {
        return (undef,$@);
    } elsif ($rows[0]>0) {
        eval{
            @rows = ExecSQL($dbuser, $dbpasswd, "update pfm_portfolioHoldings set num_shares = num_shares + ? where portfolio_id = ? and symbol = ?", undef, $amount, $pid, $symb)
        };
    } else {
        
        eval{
            @rows = ExecSQL($dbuser, $dbpasswd, "insert into pfm_portfolioHoldings(portfolio_id, symbol, num_shares, timestamp, purchase_price) values (?, ?, ?, ?, ?)", undef, $pid, $symb, $amount, $currentTime, $price)
        };
    }
    
    return @;
}

sub SellStock {
    my($amount, $symb, $pid) = @_;
    my $currentTime = time();
    my @rows;
    my $price = getRecentPrice($symb);
    eval{
        @rows = ExecSQL($dbuser, $dbpasswd, "update pfm_portfolioHoldings set num_shares = num_shares - ? where portfolio_id = ? and symbol = ?", undef, $amount, $pid, $symb)
    };
    if ($@) {
        return (undef,$@);
    } else {
        eval{
            ExecSQL($dbuser, $dbpasswd, "delete from pfm_portfolioHoldings where num_shares = 0", undef)
        };
        return @;
    }
}

sub getStocks {
    my ($pid) = @_;
    my @rows;
    eval {
        @rows = ExecSQL($dbuser, $dbpasswd, "select symbol from pfm_portfolioHoldings where portfolio_id = ?", undef, $pid);
    };
    if($@) {
        return (undef, $@);
    } else {
        return (MakeRaw('stock-list', '2D',@rows), $@);
    }
}


sub RecordPrice{
    my ($symb, $high, $low, $close, $open, $volume) = @_;
    my @rows;
    my $date= time();
    eval{
        @rows= ExecSQL($dbuser, $dbpasswd, "insert into pfm_stocksData(symbol, timestamp, high, low, close, open, volume) values (?, ?, ?, ?, ?, ?, ?)", undef, $symb, $date, $high, $low, $close, $open, $volume);
    };
    return $@;
}
#
# Add a portfolio to a user's account
# call with portfolio name
#
# returns false on success, error string on failure.
#
# PortfolioAdd($portfolio_name)
#
sub PortfolioAdd {
    my ($name) = @_;
    my $id = int(rand(10000000000000000));
    eval { ExecSQL($dbuser,$dbpasswd,
        "insert into pfm_portfolios(portfolio_id,user_id,portfolio_name,cash) values (?,?,?,0)",undef,$id,$user,$name);};
    return $@;
}

#
# Add a user
# call with user_name,password
#
# returns false on success, error string on failure.
#
# UserAdd($user_name,$password)
#
sub UserAdd {
    eval { ExecSQL($dbuser,$dbpasswd,
        "insert into pfm_users(user_name,password) values (?,?)",undef,@_);};
    return $@;
}

#
#
# Check to see if user_name and password combination exist
#
# $ok = ValidUser($user_name,$password)
#
#
sub ValidUser {
    my ($user_name,$password)=@_;
    my @col;
    eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from pfm_users where user_name=? and password=?","COL",$user_name,$password);};
    if ($@) {
        return 0;
    } else {
        return $col[0]>0;
    }
}

#
#
# Check to see if user_name is new
#
# $ok = NewUser($user_name)
#
#
sub NewUser {
    my ($user_name)=@_;
    my @col;
    eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from pfm_users where user_name=?","COL",$user_name);};
    if ($@) {
        return 0;
    } else {
        return $col[0]==0;
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

sub MakeLinkedTable {
    my ($id,$type,$headerlistref,$linkbase,@list)=@_;
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
            $out.= join("",map {"<tr>$_</tr>"} (map {MakeLinkedRow($linkbase,@{$_})} @list));
        }
        $out.="</table>";
    } else {
        # if no header row or list, then just say none.
        $out.="(none)";
    }
    return $out;
}

sub MakeLinkedRow {
    my ($linkbase, $first, @rest)=@_;
    $first = "<td><a href=\"pfm.pl?act=$linkbase$first\">$first</a></td>";
    my $rest = join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @rest);
    return $first.$rest;

    {join("",map {MakeLinkedRow($_)} @{$_})}
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
        $ENV{PORTF_DBMS}="oracle";
        $ENV{PORTF_DB}="cs339";
        $ENV{PORTF_DBUSER}="ndh242";
        $ENV{PORTF_DBPASS}="zo06aFIky";

        $ENV{PATH} = $ENV{PATH}.":."; 
        exec 'env',cwd().'/'.$0,@ARGV;
    }
}

