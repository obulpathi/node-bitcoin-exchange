var pg = require('pg'), crypto = require('crypto'), config = require('./../config.js');

var conString = "tcp://" + config.pg.username + ":" + config.pg.password + "@" + config.pg.host + "/" + config.pg.db;

var pg_client = new pg.Client(conString);
pg_client.connect();

var Account = module.exports = function ()
{
	this.id = null;
	this.api_key = null;
}

Account.prototype.login = function (token, callback)
{
	var self = this;

	if ( typeof token.id == 'undefined' || typeof token.timestamp == 'undefined' || typeof token.hash == 'undefined' ) {
		callback('bad token format', null);
		return;
	}

	pg_client.query({
		name   : 'select api key',
		text   : "SELECT password FROM users WHERE id = $1",
		values : [token.id]
	}, function (err, result)
	{
		if ( result.rows.length == 0 ) {
			callback('authentication failed', null);
		} else {
			self.api_key = result.rows[0].password;

			var shasum = crypto.createHash('sha1');
			shasum.update(self.api_key + token.timestamp);

			if ( shasum.digest('hex') != token.hash ) {
				callback('authentication failed', null);
				return;
			}

			self.id = token.id;

			callback();
		}
	});
}

Account.prototype.cmd = function (data, callback)
{
	var str_payload = JSON.stringify(data.payload);
	var shasum = crypto.createHash('sha1');

	shasum.update(this.api_key + data.timestamp + str_payload);

	if ( data.hash != shasum.digest('hex') ) {
		callback('hash does not match');
		return;
	}

	callback();
}

Account.prototype.new_order = function (data, callback)
{

// Check types

	var order_types = [
		'gtc'
		, 'iok'
//		, 'fok'  // Soon
	];

	if ( typeof data.type == 'undefined' || order_types.indexOf(data.type.toLowerCase()) === -1 ) {
		callback('missing/incorrect order type');
		return;
	}

// Check symbol

	var symbols = new Array();

	symbols[2] = 'btcusd';
	symbols[3] = 'btceur';
	symbols[4] = 'btcgbp';

	//symbols[5] = 'xaubtc';

	if ( typeof data.symbol == 'undefined' || symbols.indexOf(data.symbol.toLowerCase()) === -1 ) {
		callback('missing/incorrect symbol');
		return;
	}

// Check symbol

	if ( typeof data.buy_sell == 'undefined' || ( data.buy_sell !== true && data.buy_sell !== false) ) {
		callback('missing/incorrect buy/sell');
		return;
	}

// Check price

	if ( typeof data.price != 'number' || data.price <= 0 || data.price >= 99999 ) {
		callback('missing/incorrect price');
		return;
	}

// Check expire

	if ( typeof data.expire != 'undefined' ) {
		try {
			var expire = new Date(data.expire);
		} catch ( e ) {
			callback('missing/incorrect expire date');
			return;
		}

		if ( new Date(data.expire) <= new Date() ) {
			callback('missing/incorrect expire date');
			return;
		}

	} else {
		var expire = "NOW() + interval '1 year'";
	}

// Check amount

	if ( typeof data.amount != 'number' || data.amount <= 0 || data.amount > 21000000 ) {
		callback('missing/incorrect amount');
		return;
	}

// Checks finished

	var arr_order = [
		symbols.indexOf(data.symbol.toLowerCase()), this.id, expire, data.buy_sell, data.price, data.amount,
		data.amount, 'active', data.type.toLowerCase()
	];

	pg_client.query({
		name   : 'Placing order',
		text   : "INSERT INTO orders_limit VALUES ( nextval('orders_id_seq'::regclass),$1,$2,NOW(),$3 ,$4,$5,$6,$7,$8,$9) RETURNING id",
		values : arr_order
	}, function (err, result)
	{
		if ( err ) {
			callback(err);
			return;
		}

		callback(null, result.rows[0].id);
	});

}