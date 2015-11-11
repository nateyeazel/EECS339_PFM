create table pfm_users(
    user_name varchar2(64) not null primary key,
    password varchar2(64) not null,
        constraint passwd_length check (password like '______%')
);
create table pfm_portfolios(
    portfolio_id number not null unique,
    user_id varchar2(64) not null references pfm_users(user_name),
    portfolio_name varchar2(64) not null,
    cash number,
    primary key(portfolio_name, user_id),
    CONSTRAINT no_debt CHECK (cash >= 0)
);
create table pfm_portfolioHoldings(
	portfolio_id number not null references pfm_portfolios(portfolio_id),
	symbol varchar2(16) not null references pfm_stocks(symbol),
	num_shares number not null,
    timestamp number not null,
	purchase_price number not null,
	primary key(portfolio_id, symbol),
    CONSTRAINT no_shorts CHECK (num_shares >= 0)
);
create table pfm_stocks(
	symbol varchar2(16) not null primary key
);
create table pfm_stocksData(
	symbol varchar2(8) not null references pfm_stocks(symbol),
	timestamp number not null,
	high number not null,
	low number not null,
	close number not null,
	open number not null,
	volume number not null,
    primary key(symbol, timestamp)
);
create view allStockData as
    select symbol, timestamp, close from cs339.StocksDaily
    union
    select symbol, timestamp, close from pfm_stocksData;
create table pfm_portfolioStats(
    portfolio_id number not null primary key references pfm_portfolios(portfolio_id),
    statistic number not null
);
