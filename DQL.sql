--User check
select count(*) from pfm_users where user_name=? and password=?
--New account
insert into table pfm_users(user_name, password) values(?, ?)
-- List of portfolios
select portfolio_name, cash from pfm_portfolios where user_name=?
-- Add new portfolio
insert into table pfm_portfolios(portfolio_id, user_name, portfolio_name, cash) values(?, ?, ?, 0)

--PORTFOLIO MAIN PAGE WILL GO HERE
--Display cash value
select cash from table pfm_portfolios where portfolio_id = ?

--Display all stock holdings
select symbol, num_shares, purchase_price from pfm_portfolioHoldings where portfolio_id = ?

--Get current prices of stocks
--NOTE: Doesn't actually work REWRITE!
select close from pfm_stocksData union select close from cs339.StocksDaily where symbol in (?) and max(timestamp)

-- Get the volatility of a stock
-- ?????

-- Deposit/Withdraw from cash account
update pfm_portfolios set cash = cash + ? where portfolio_id = ?

-- Record new stock bought
insert into pfm_portfolioHoldings(portfolio_id, symbol, num_shares, timestamp, purchase_price) values (?, ?, ?, ?, ?)

-- Buy/Sell stock already owned
update pfm_portfolioHoldings set num_shares = num_shares + ? where portfolio_id = ? and symbol = ?

-- Sell all of stock currently owned
delete from pfm_portfolioHoldings where portfolio_id = ? and symbol = ?

-- Record new stock info
insert into table pfm_stocksData(symbol, timestamp, high, low, close, open, volume) values (?, ?, ?, ?, ?, ?, ?)

--Stock main page
--Call into get_data.pl and also stocksData table
select timestamp, close from pfm_stocksData where symbol = ? and timestamp < ? and timestamp > ?

--Future predictions 
--Call into markov_symbol.pl
