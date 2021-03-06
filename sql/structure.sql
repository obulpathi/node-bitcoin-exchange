--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

ALTER TABLE ONLY public.users DROP CONSTRAINT users_currency_fkey;
ALTER TABLE ONLY public.users_btc DROP CONSTRAINT users_btc_users_fkey;
ALTER TABLE ONLY public.transfers DROP CONSTRAINT transfers_users_fkey;
ALTER TABLE ONLY public.transfers DROP CONSTRAINT transfers_symbol_fkey;
ALTER TABLE ONLY public.transfers_codes DROP CONSTRAINT transfers_codes_id_fkey;
ALTER TABLE ONLY public.transfers_codes DROP CONSTRAINT transfers_codes_deposit_id_fkey;
ALTER TABLE ONLY public.transfers_btc DROP CONSTRAINT transfers_btc_id_fkey;
ALTER TABLE ONLY public.transfers_btc DROP CONSTRAINT transfers_btc_address_fkey;
ALTER TABLE ONLY public.orders_stop DROP CONSTRAINT orders_stop_users_fkey;
ALTER TABLE ONLY public.orders_stop DROP CONSTRAINT orders_stop_symbol_fkey;
ALTER TABLE ONLY public.orders_limit DROP CONSTRAINT orders_limit_users_fkey;
ALTER TABLE ONLY public.orders_limit DROP CONSTRAINT orders_limit_symbol_fkey;
ALTER TABLE ONLY public.matched DROP CONSTRAINT matched_sell_fkey;
ALTER TABLE ONLY public.matched DROP CONSTRAINT matched_buy_fkey;
ALTER TABLE ONLY public.balances DROP CONSTRAINT balances_user_fkey;
ALTER TABLE ONLY public.balances DROP CONSTRAINT balances_symbol_fkey;
DROP TRIGGER t_upd_stopout ON public.symbols;
DROP TRIGGER t_upd_balance ON public.balances;
DROP TRIGGER t_trans_btc ON public.transfers_btc;
DROP TRIGGER t_new_order ON public.orders_limit;
DROP TRIGGER t_new_addr ON public.users_btc;
DROP TRIGGER t_balance ON public.users;
DROP INDEX public.i_users2;
DROP INDEX public.i_users;
DROP INDEX public.i_ol_dt;
ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
ALTER TABLE ONLY public.users DROP CONSTRAINT users_email_key;
ALTER TABLE ONLY public.users_btc DROP CONSTRAINT users_btc_pkey;
ALTER TABLE ONLY public.transfers DROP CONSTRAINT transfers_pkey;
ALTER TABLE ONLY public.transfers_codes DROP CONSTRAINT transfers_codes_id_key;
ALTER TABLE ONLY public.transfers_codes DROP CONSTRAINT transfers_codes_deposit_id_key;
ALTER TABLE ONLY public.transfers_codes DROP CONSTRAINT transfers_codes_code_key;
ALTER TABLE ONLY public.transfers_btc DROP CONSTRAINT transfers_btc_trans_key;
ALTER TABLE ONLY public.transfers_btc DROP CONSTRAINT transfers_btc_id_key;
ALTER TABLE ONLY public.symbols DROP CONSTRAINT symbols_symbol_key;
ALTER TABLE ONLY public.symbols DROP CONSTRAINT symbols_pkey;
ALTER TABLE ONLY public.orders_stop DROP CONSTRAINT orders_stop_pkey;
ALTER TABLE ONLY public.orders_limit DROP CONSTRAINT orders_id_key;
ALTER TABLE ONLY public.matched DROP CONSTRAINT matched_buy_sell_key;
ALTER TABLE ONLY public.fees DROP CONSTRAINT fees_pkey;
ALTER TABLE ONLY public.balances DROP CONSTRAINT balances_user_symbol_key;
ALTER TABLE public.users_btc ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.transfers ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.symbols ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.orders_stop ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.orders_limit ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.fees ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE public.users_id_seq;
DROP SEQUENCE public.users_btc_id_seq;
DROP TABLE public.users_btc;
DROP TABLE public.users;
DROP SEQUENCE public.transfers_id_seq;
DROP TABLE public.transfers_codes;
DROP TABLE public.transfers_btc;
DROP TABLE public.transfers;
DROP SEQUENCE public.symbols_id_seq;
DROP TABLE public.symbols;
DROP SEQUENCE public.orders_stop_id_seq;
DROP TABLE public.orders_stop;
DROP SEQUENCE public.orders_id_seq;
DROP TABLE public.orders_limit;
DROP TABLE public.matched;
DROP SEQUENCE public.fees_id_seq;
DROP TABLE public.fees;
DROP TABLE public.balances;
DROP FUNCTION public.t_usr_btc_new();
DROP FUNCTION public.t_upd_balance();
DROP FUNCTION public.t_stopout();
DROP FUNCTION public.t_order_match();
DROP FUNCTION public.t_fee_bal();
DROP FUNCTION public.t_balance_acc();
DROP FUNCTION public.symbol_update_bidask(v_symbol integer);
DROP FUNCTION public.new_order(v_symbol integer, v_user integer, v_expire timestamp without time zone, v_buy_sell boolean, v_price numeric, v_amount numeric, v_type character varying);
DROP FUNCTION public.issue_code(v_users integer, v_symbol integer, v_amount numeric, v_code character varying);
DROP FUNCTION public.get_book(v_symbol integer, v_grid numeric, v_inverted boolean);
DROP FUNCTION public.fee(v_users integer, v_type character varying, v_amount numeric, v_order_id integer);
DROP FUNCTION public.deposit_code(v_users integer, v_code character varying);
DROP FUNCTION public.buying_power(v_users integer);
DROP FUNCTION public.btc_trans_conf();
DROP FUNCTION public.btc_deposit(v_trans_id character varying, v_address character varying, v_amount numeric);
DROP EXTENSION plpgsql;
DROP SCHEMA public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: btc_deposit(character varying, character varying, numeric); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION btc_deposit(v_trans_id character varying, v_address character varying, v_amount numeric) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_transfer_id	integer;
	v_address_id	integer;
BEGIN

	SELECT
		id
	INTO
		v_address_id
	FROM
		users_btc
	WHERE
		address = v_address;

	IF NOT FOUND THEN
		RETURN 'unknown address';
	END IF;

	-- Checking if already inserted

	PERFORM
		id
	FROM
		transfers_btc
	WHERE
		trans = v_trans_id;

	IF FOUND THEN
		RETURN 'transaction exits';
	END IF;

	-- Inserting transfer record

	INSERT INTO
		transfers(
			dt,
			users,
			in_out,
			symbol,
			amount,
			status
		)
	VALUES(
		now(),
		(SELECT users FROM users_btc WHERE address = v_address),
		TRUE,
		1,
		v_amount,
		'progress'
	) RETURNING id INTO v_transfer_id;

	-- Inserting transaction record

	INSERT INTO
		transfers_btc( id, trans, address )
	VALUES ( v_transfer_id, v_trans_id, v_address_id);

	RETURN 'inserted';
END;
$$;


ALTER FUNCTION public.btc_deposit(v_trans_id character varying, v_address character varying, v_amount numeric) OWNER TO exchange;

--
-- Name: FUNCTION btc_deposit(v_trans_id character varying, v_address character varying, v_amount numeric); Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON FUNCTION btc_deposit(v_trans_id character varying, v_address character varying, v_amount numeric) IS 'Affecting transfers and transfers_btc';


--
-- Name: btc_trans_conf(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION btc_trans_conf() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_transfer_id	integer;
	v_amount	numeric;
	v_users		integer;
BEGIN

	IF ( NEW.conf >= 6 ) THEN

		-- Checking if already processed

		SELECT
			id, users, amount
		INTO
			v_transfer_id, v_users, v_amount
		FROM
			transfers
		WHERE
			id = OLD.id
			AND status = 'progress';

		IF NOT FOUND THEN
			RETURN NEW;
		END IF;

		-- Writing old balance

		UPDATE
			transfers as t
		SET
			balance = (
				SELECT
					balance
				FROM
					balances
				WHERE
					symbol = 1
					AND users = t.users
			),
			status = 'processed',
			dt_status = now()
		WHERE
			id = OLD.id;

		-- Credit transfer amount to balance

		UPDATE
			balances
		SET
			balance = balance + v_amount
		WHERE
			symbol = 1
			AND users = v_users;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.btc_trans_conf() OWNER TO exchange;

--
-- Name: FUNCTION btc_trans_conf(); Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON FUNCTION btc_trans_conf() IS 'Bitcoin transactions confirmation logic';


--
-- Name: buying_power(integer); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION buying_power(v_users integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN SUM( CASE
			WHEN b.balance > 0 THEN
				b.balance * s.bid
			WHEN b.balance < 0 THEN
				b.balance * s.ask
		END ) as power
	FROM
		balances as b
		LEFT JOIN symbols as s ON b.symbol = s.id
	WHERE
		users = v_users
		AND balance != 0;
END;$$;


ALTER FUNCTION public.buying_power(v_users integer) OWNER TO exchange;

--
-- Name: deposit_code(integer, character varying); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION deposit_code(v_users integer, v_code character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_deposit_id	integer;
	v_issue_id	integer;
	v_symbol	integer;
	v_amount	numeric;
BEGIN

	SELECT
		t.id, t.symbol, t.amount
	INTO
		v_issue_id, v_symbol, v_amount
	FROM
		transfers_codes as c
		LEFT JOIN transfers as t ON t.id = c.id
	WHERE
		c.code = v_code
		AND c.deposit_id IS NULL
		AND t.status = 'issued';

	IF NOT FOUND THEN
		RETURN FALSE;
	END IF;

	-- Processing code - transfer record

	INSERT INTO
		transfers(
			dt,
			users,
			in_out,
			symbol,
			amount,
			status,
			dt_status
		)
	VALUES(
		now(),
		v_users,
		TRUE,
		v_symbol,
		v_amount,
		'deposited',
		now()
	) RETURNING id INTO v_deposit_id;

	-- Processing code - updating code depositor

	UPDATE
		transfers_codes
	SET
		deposit_id = v_deposit_id
	WHERE
		id = v_issue_id;

	-- Processing code - updating issue transfer

	UPDATE
		transfers
	SET
		status = 'deposited',
		dt_status = now()
	WHERE
		id = v_issue_id;

	-- Updating prior balance

	UPDATE
		transfers
	SET
		balance = (
			SELECT
				balance
			FROM
				balances
			WHERE
				users = v_users
				AND symbol = v_symbol
		)
	WHERE
		id = v_deposit_id;

	-- Credit balance

	UPDATE
		balances
	SET
		balance = balance + v_amount
	WHERE
		users = v_users
		AND symbol = v_symbol;

	-- Fee

	PERFORM fee(v_users, 'code deposit', 0.01, v_issue_id);

	RETURN TRUE;
END;
$$;


ALTER FUNCTION public.deposit_code(v_users integer, v_code character varying) OWNER TO exchange;

--
-- Name: FUNCTION deposit_code(v_users integer, v_code character varying); Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON FUNCTION deposit_code(v_users integer, v_code character varying) IS 'Depositing existing code';


--
-- Name: fee(integer, character varying, numeric, integer); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION fee(v_users integer, v_type character varying, v_amount numeric, v_order_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_fee_id	integer;
BEGIN

	-- Making fee record

	INSERT INTO
		fees( dt, users, fee_type, amount )
	VALUES (
		now(),
		v_users,
		v_type,
		v_amount
	) RETURNING id INTO v_fee_id;

	-- Debit user balance

	UPDATE
		balances
	SET
		balance = balance - v_amount
	WHERE
		users = v_users
		AND symbol = 1;

	-- Credit exchange fee account

	UPDATE
		balances
	SET
		balance = balance + v_amount
	WHERE
		users = 1
		AND symbol = 1;


	-- Finalising fee

	CASE v_type
		WHEN 'order fail' THEN

			UPDATE
				fees
			SET
				order_id = v_order_id
			WHERE
				id = v_fee_id;

			UPDATE
				orders_limit
			SET
				status = 'fail'
			WHERE
				id = v_order_id;

		WHEN 'order match' THEN

			UPDATE
				fees
			SET
				order_id = v_order_id
			WHERE
				id = v_fee_id;

		WHEN 'order cancel' THEN

			UPDATE
				fees
			SET
				order_id = v_order_id
			WHERE
				id = v_fee_id;

		WHEN 'code deposit' THEN

			UPDATE
				fees
			SET
				order_id = v_order_id
			WHERE
				id = v_fee_id;
		ELSE
			v_order_id = v_order_id;
	END CASE;
END;
$$;


ALTER FUNCTION public.fee(v_users integer, v_type character varying, v_amount numeric, v_order_id integer) OWNER TO exchange;

--
-- Name: get_book(integer, numeric, boolean); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION get_book(v_symbol integer, v_grid numeric, v_inverted boolean) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
BEGIN

	IF v_inverted = TRUE THEN

		RETURN QUERY

		SELECT
			CASE buy_sell
				WHEN TRUE THEN floor( 1 / ( price * v_grid )) * v_grid
				WHEN FALSE THEN ceil( 1 / ( price * v_grid )) * v_grid
			END,
			buy_sell,
			SUM(unfilled) size
		FROM
			orders_limit
		WHERE
			symbol = v_symbol
			AND status = 'active'
			AND exp_dt >= NOW()
			AND unfilled > 0
		GROUP BY
			buy_sell, CASE buy_sell
				WHEN TRUE THEN floor( 1 / ( price * v_grid )) * v_grid
				WHEN FALSE THEN ceil( 1 / ( price * v_grid )) * v_grid
			END
		ORDER BY
			buy_sell, CASE buy_sell
				WHEN TRUE THEN floor( 1 / ( price * v_grid )) * v_grid
				WHEN FALSE THEN ceil( 1 / ( price * v_grid )) * v_grid
			END DESC;

	ELSE

		RETURN QUERY

		SELECT
			CASE buy_sell
				WHEN TRUE THEN floor(price / v_grid) * v_grid
				WHEN FALSE THEN ceil(price / v_grid) * v_grid
			END,
			buy_sell,
			SUM(unfilled) size
		FROM
			orders_limit
		WHERE
			symbol = v_symbol
			AND status = 'active'
			AND exp_dt >= NOW()
			AND unfilled > 0
		GROUP BY
			buy_sell, CASE buy_sell
				WHEN TRUE THEN floor(price / v_grid) * v_grid
				WHEN FALSE THEN ceil(price / v_grid) * v_grid
			END
		ORDER BY
			buy_sell, CASE buy_sell
				WHEN TRUE THEN floor(price / v_grid) * v_grid
				WHEN FALSE THEN ceil(price / v_grid) * v_grid
			END DESC;

	END IF;

END;
$$;


ALTER FUNCTION public.get_book(v_symbol integer, v_grid numeric, v_inverted boolean) OWNER TO exchange;

--
-- Name: issue_code(integer, integer, numeric, character varying); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION issue_code(v_users integer, v_symbol integer, v_amount numeric, v_code character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_transfer_id	integer;
BEGIN
	-- Checking if enough money on balance

	PERFORM	* FROM
		balances
	WHERE
		users = v_users
		AND symbol = v_symbol
		AND balance - v_amount >= 0;

	IF NOT FOUND THEN
		RETURN FALSE;
	END IF;

	-- Making codes - transfer record

	INSERT INTO
		transfers(
			dt,
			users,
			in_out,
			symbol,
			amount,
			status
		)
	VALUES(
		now(),
		v_users,
		FALSE,
		v_symbol,
		v_amount,
		'issued'
	) RETURNING id INTO v_transfer_id;

	-- Making codes - code record

	INSERT INTO
		transfers_codes(id, code)
	VALUES( v_transfer_id, v_code);

	-- Updating prior balance

	UPDATE
		transfers
	SET
		balance = (
			SELECT
				balance
			FROM
				balances
			WHERE
				users = v_users
				AND symbol = v_symbol
		)
	WHERE
		id = v_transfer_id;

	-- Debit from balance

	UPDATE
		balances
	SET
		balance = balance - v_amount
	WHERE
		users = v_users
		AND symbol = v_symbol;

	RETURN TRUE;
END;
$$;


ALTER FUNCTION public.issue_code(v_users integer, v_symbol integer, v_amount numeric, v_code character varying) OWNER TO exchange;

--
-- Name: new_order(integer, integer, timestamp without time zone, boolean, numeric, numeric, character varying); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION new_order(v_symbol integer, v_user integer, v_expire timestamp without time zone, v_buy_sell boolean, v_price numeric, v_amount numeric, v_type character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_order_id	integer;
BEGIN

	IF ( v_type = 'stop' ) THEN

		INSERT INTO
			orders_stop(
				symbol,
				users,
				dt,
				exp_dt,
				buy_sell,
				price,
				amount
			)
		VALUES(
			v_symbol,
			v_user,
			now(),
			v_expire,
			v_buy_sell,
			v_price,
			v_amount
		) RETURNING id INTO v_order_id;
	ELSE

		INSERT INTO
			orders_limit(
				symbol,
				users,
				dt,
				exp_dt,
				buy_sell,
				price,
				amount,
				unfilled,
				types,
				status
			)
		VALUES(
			v_symbol,
			v_user,
			now(),
			v_expire,
			v_buy_sell,
			v_price,
			v_amount,
			v_amount,
			v_type,
			'active'
		) RETURNING id INTO v_order_id;

	END IF;

	RETURN v_order_id;
END;
$$;


ALTER FUNCTION public.new_order(v_symbol integer, v_user integer, v_expire timestamp without time zone, v_buy_sell boolean, v_price numeric, v_amount numeric, v_type character varying) OWNER TO exchange;

--
-- Name: symbol_update_bidask(integer); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION symbol_update_bidask(v_symbol integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
        v_bid   numeric(9,5);
        v_ask   numeric(9,5);
BEGIN

        SELECT
                price
        INTO
                v_bid
        FROM
                orders_limit
        WHERE
                symbol = v_symbol
                AND buy_sell = TRUE
                AND status = 'active'
                AND unfilled > 0
        ORDER BY
                price DESC
        LIMIT 1;

        SELECT
                price
        INTO
                v_ask
        FROM
                orders_limit
        WHERE
                symbol = v_symbol
                AND buy_sell = FALSE
                AND status = 'active'
                AND unfilled > 0
        ORDER BY
                price DESC
        LIMIT 1;

        UPDATE
                symbols
        SET
                bid = COALESCE(v_bid, 0),
                ask = COALESCE(v_ask, 0)
        WHERE
                id = v_symbol;

	PERFORM pg_notify('scout', 'symbols,' || v_symbol || ',' || COALESCE(v_bid, 0) || ',' || COALESCE(v_ask, 0) );

END;$$;


ALTER FUNCTION public.symbol_update_bidask(v_symbol integer) OWNER TO exchange;

--
-- Name: t_balance_acc(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_balance_acc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	INSERT INTO
		balances (users, symbol, balance)
	SELECT
		NEW.id, id,0
	FROM
		symbols;

	RETURN NEW;
END
$$;


ALTER FUNCTION public.t_balance_acc() OWNER TO exchange;

--
-- Name: t_fee_bal(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_fee_bal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE
		balances
	SET
		balance = balance - NEW.amount
	WHERE
		users = NEW.users
		AND symbol = 1;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_fee_bal() OWNER TO exchange;

--
-- Name: t_order_match(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_order_match() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	c_orders	refcursor;
	v_order		record;
	v_unfilled	numeric(8,2);
	v_effective     numeric(8,2);
	v_bp_my         numeric(12,2);
	v_bp_his        numeric(12,2);
	v_margin	integer;
BEGIN

	PERFORM pg_notify('scout', TG_TABLE_NAME || ',' || NEW.users || ',' || NEW.id );

	IF NEW.buy_sell = TRUE THEN
		OPEN c_orders FOR SELECT
			*
		FROM
			orders_limit as o
		WHERE
			o.buy_sell = false
			AND o.symbol = NEW.symbol
			AND o.status = 'active'
			AND o.exp_dt >= NOW()
			AND o.unfilled > 0
			AND o.price <= NEW.price
			AND o.users != NEW.users
		ORDER BY
			o.price ASC;
	ELSE
		OPEN c_orders FOR SELECT
			*
		FROM
			orders_limit as o
		WHERE
			o.buy_sell = true
			AND o.symbol = NEW.symbol
			AND o.status = 'active'
			AND o.exp_dt >= NOW()
			AND o.unfilled > 0
			AND o.price >= NEW.price
			AND o.users != NEW.users
		ORDER BY
			o.price DESC;

	END IF;

	-- Getting symbol margin levels

	SELECT
		margin / 100
	INTO
		v_margin
	FROM
		symbols
	WHERE
		id = NEW.symbol;

	v_unfilled = NEW.unfilled;

	LOOP
		FETCH c_orders INTO v_order;

		-- If not found match

		IF NOT FOUND THEN
			EXIT;
		END IF;

		-- Getting effective matched volume

		v_bp_his	= buying_power(v_order.users);

		IF v_bp_his <= 0 THEN
			PERFORM fee( v_order.users, 'order fail', (v_order.unfilled * v_order.price) * 0.02, v_order.id );
			CONTINUE;
		END IF;

		IF v_bp_his >= v_order.unfilled * v_order.price * v_margin THEN
			v_effective = v_order.unfilled;
		ELSE
			v_effective = v_bp_his / v_margin;
			PERFORM fee( v_order.users, 'order fail', (v_order.unfilled * v_order.price * v_margin - v_bp_his) * 0.02, v_order.id );
		END IF;

		v_bp_my	= buying_power(NEW.users);

		IF v_bp_my <= 0 THEN
			PERFORM fee( NEW.users, 'order fail', (v_unfilled * v_order.price * v_margin * 1.003) * 0.02, NEW.id);
			EXIT;
		END IF;

		-- If v_unfilled is less than v_effective

		IF v_unfilled < v_effective THEN
			v_effective = v_unfilled;
		END IF;

		IF v_bp_my < v_effective * v_order.price * v_margin * 1.003 THEN
			v_effective = v_bp_my / v_margin;
			PERFORM fee( NEW.users, 'order fail', (v_unfilled * v_order.price * v_margin * 1.003 - v_bp_my ) * 0.02, NEW.id);
		END IF;

		-- Updating balances + orders

		-- Updating my BTC balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance - v_order.price * v_effective * 1.003
				ELSE
					balance + v_order.price * v_effective
				END
		WHERE
			users = NEW.users
			AND symbol = 1;

		-- Updating my fiat balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance + v_effective
				ELSE
					balance - v_effective * 1.003
				END
		WHERE
			users = NEW.users
			AND symbol = NEW.symbol;

		-- Updating his BTC balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance + v_order.price * v_effective * 1.001
				ELSE
					balance - v_order.price * v_effective
				END
		WHERE
			users = v_order.users
			AND symbol = 1;

		-- Updating his fiat balance

		UPDATE
			balances
		SET
			balance = CASE
				WHEN NEW.buy_sell = TRUE THEN
					balance - v_effective
				ELSE
					balance + v_effective * 1.001
				END
		WHERE
			users = v_order.users
			AND symbol = NEW.symbol;

		-- Updating orders

		UPDATE
			orders_limit
		SET
			unfilled = unfilled - v_effective,
			status = CASE
					WHEN unfilled - v_effective = 0 THEN
						'filled'
					ELSE
						status
				END
		WHERE
			id = NEW.id OR id = v_order.id;

		-- Inserting match

		IF NEW.buy_sell = TRUE THEN
			INSERT INTO matched (buy, sell, amount ) VALUES ( NEW.id, v_order.id, v_effective );
		ELSE
			INSERT INTO matched (buy, sell, amount ) VALUES ( v_order.id, NEW.id, v_effective );
		END IF;

		PERFORM pg_notify('scout', 'matched,' || NEW.symbol || ',' || v_order.price || ',' || v_effective);

		-- Taking fee

		PERFORM fee( NEW.users, 'order match', v_effective * v_order.price * 0.002, NEW.id);

		-- Updating last trade for symbol

		UPDATE
			symbols
		SET
			last_price = v_order.price,
			last_dt = now(),
			bid	= CASE
					WHEN NEW.buy_sell = FALSE THEN v_order.price
					ELSE bid
				END,
			ask	= CASE
					WHEN NEW.buy_sell = TRUE THEN v_order.price
					ELSE ask
				END
		WHERE
			id = NEW.symbol;

		-- Updating unfilled amount

		v_unfilled = v_unfilled - v_effective;

		EXIT WHEN v_unfilled = 0 OR v_bp_my < v_effective;

	END LOOP;

	CLOSE c_orders;

	IF NEW.types = 'iok' AND v_unfilled > 0 THEN
		UPDATE
			orders_limit
		SET
			status = 'filled'
		WHERE
			id = NEW.id;
	END IF;

	PERFORM symbol_update_bidask(NEW.symbol);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_order_match() OWNER TO exchange;

--
-- Name: t_stopout(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_stopout() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	c_users	refcursor;
	v_user	record;
	v_bp	numeric(12,2);
BEGIN

	-- If not connected to bid/ask change

	IF NEW.bid = OLD.bid AND NEW.ask = OLD.ask THEN
		RETURN NEW;
	END IF;

	-- Get pretenders

	OPEN c_users FOR SELECT
		users
	FROM
		balances
	WHERE
		balance < 0
		AND symbol = NEW.id;

	LOOP
		FETCH c_users INTO v_user;

		-- No more

		IF NOT FOUND THEN
			EXIT;
		END IF;

		-- Getting 90% buying power for debit balances

		SELECT SUM( CASE
			WHEN b.balance > 0 THEN
				b.balance * s.bid * 0.9
			WHEN b.balance < 0 THEN
				b.balance * s.ask
			END ) as power
		INTO
			v_bp
		FROM
			balances as b
			LEFT JOIN symbols as s ON b.symbol = s.id
		WHERE
			users = v_user.users
			AND balance != 0;

		-- Justice

		INSERT INTO
			orders_limit
		SELECT
			nextval('orders_id_seq'::regclass),
			2,
			b.users,
			NOW(),
			NOW() + INTERVAL '365 day',
			CASE WHEN b.balance > 0 THEN TRUE ELSE FALSE END as buy_sell,
			CASE WHEN b.balance > 0 THEN 9999 ELSE 0.0001 END as price,
			@b.balance,
			@b.balance,
			'active',
			'gtc'
		FROM
			balances as b
		WHERE
			v_bp <= 0
			AND b.users = v_user.users
			AND b.symbol = 1;
	END LOOP;

	CLOSE c_users;

	-- Flushing stop orders if any

	INSERT INTO
		orders_limit(
			symbol,
			users,
			dt,
			exp_dt,
			buy_sell,
			price,
			amount,
			unfilled,
			status,
			types
		)
	SELECT
		symbol,
		users,
		dt,
		exp_dt,
		buy_sell,
		CASE buy_sell
			WHEN TRUE THEN 9999
			ELSE 0.00001
		END,
		amount,
		amount,
		'active',
		'gtc'
	FROM
		orders_stop
	WHERE
		symbol = NEW.id
		AND (
			( buy_sell = TRUE AND NEW.ask >= price AND OLD.ask < price )
			OR
			( buy_sell = FALSE AND NEW.bid <= price AND OLD.bid > price )
		);

	-- Delete them here

	DELETE FROM
		orders_stop
	WHERE
		symbol = NEW.id
		AND (
			( buy_sell = TRUE AND NEW.ask >= price AND OLD.ask < price )
			OR
			( buy_sell = FALSE AND NEW.bid <= price AND OLD.bid > price )
		);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_stopout() OWNER TO exchange;

--
-- Name: FUNCTION t_stopout(); Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON FUNCTION t_stopout() IS 'Stop out';


--
-- Name: t_upd_balance(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_upd_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('scout', TG_TABLE_NAME || ',' || NEW.users || ',' || NEW.symbol || ',' || NEW.balance);
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_upd_balance() OWNER TO exchange;

--
-- Name: t_usr_btc_new(); Type: FUNCTION; Schema: public; Owner: exchange
--

CREATE FUNCTION t_usr_btc_new() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	NEW.dt = NOW();
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.t_usr_btc_new() OWNER TO exchange;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: balances; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE balances (
    users integer NOT NULL,
    symbol smallint NOT NULL,
    balance numeric(14,3) NOT NULL
);


ALTER TABLE public.balances OWNER TO exchange;

--
-- Name: TABLE balances; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE balances IS 'balances';


--
-- Name: fees; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE fees (
    id integer NOT NULL,
    dt timestamp without time zone NOT NULL,
    users integer NOT NULL,
    amount numeric(8,3) NOT NULL,
    fee_type character varying(50) NOT NULL,
    order_id integer,
    descr text
);


ALTER TABLE public.fees OWNER TO exchange;

--
-- Name: TABLE fees; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE fees IS 'Misc fees';


--
-- Name: fees_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE fees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fees_id_seq OWNER TO exchange;

--
-- Name: fees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE fees_id_seq OWNED BY fees.id;


--
-- Name: matched; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE matched (
    buy integer NOT NULL,
    sell integer NOT NULL,
    amount numeric(8,1) NOT NULL
);


ALTER TABLE public.matched OWNER TO exchange;

--
-- Name: TABLE matched; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE matched IS 'matched orders';


--
-- Name: orders_limit; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE orders_limit (
    id integer NOT NULL,
    symbol smallint NOT NULL,
    users integer NOT NULL,
    dt timestamp without time zone NOT NULL,
    exp_dt timestamp without time zone,
    buy_sell boolean NOT NULL,
    price numeric(10,4) NOT NULL,
    amount numeric(8,1) NOT NULL,
    unfilled numeric(8,1) NOT NULL,
    status character varying(10) NOT NULL,
    types character varying(10) NOT NULL
);


ALTER TABLE public.orders_limit OWNER TO exchange;

--
-- Name: TABLE orders_limit; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE orders_limit IS 'limit orders';


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orders_id_seq OWNER TO exchange;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE orders_id_seq OWNED BY orders_limit.id;


--
-- Name: orders_stop; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE orders_stop (
    id integer NOT NULL,
    symbol smallint NOT NULL,
    users integer NOT NULL,
    dt timestamp without time zone NOT NULL,
    buy_sell boolean NOT NULL,
    price numeric(10,4) NOT NULL,
    amount numeric(8,1) NOT NULL,
    exp_dt timestamp without time zone NOT NULL
);


ALTER TABLE public.orders_stop OWNER TO exchange;

--
-- Name: TABLE orders_stop; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE orders_stop IS 'stop orders - sl, tp, stop outs';


--
-- Name: orders_stop_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE orders_stop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orders_stop_id_seq OWNER TO exchange;

--
-- Name: orders_stop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE orders_stop_id_seq OWNED BY orders_stop.id;


--
-- Name: symbols; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE symbols (
    id smallint NOT NULL,
    symbol character(3) NOT NULL,
    descr character varying NOT NULL,
    bid numeric(10,4) NOT NULL,
    ask numeric(10,4) NOT NULL,
    last_price numeric(10,4) NOT NULL,
    last_dt timestamp without time zone,
    margin smallint DEFAULT 50 NOT NULL,
    digits smallint DEFAULT 2 NOT NULL,
    min_size numeric(6,2) DEFAULT 1 NOT NULL
);


ALTER TABLE public.symbols OWNER TO exchange;

--
-- Name: TABLE symbols; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE symbols IS 'symbols for trade ';


--
-- Name: symbols_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE symbols_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.symbols_id_seq OWNER TO exchange;

--
-- Name: symbols_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE symbols_id_seq OWNED BY symbols.id;


--
-- Name: transfers; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE transfers (
    id integer NOT NULL,
    dt timestamp without time zone NOT NULL,
    users integer NOT NULL,
    in_out boolean NOT NULL,
    symbol smallint NOT NULL,
    amount numeric(14,3) NOT NULL,
    balance numeric(14,3),
    status character varying DEFAULT 'in progress'::character varying NOT NULL,
    dt_status timestamp without time zone
);


ALTER TABLE public.transfers OWNER TO exchange;

--
-- Name: TABLE transfers; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE transfers IS 'In/out transfers';


--
-- Name: transfers_btc; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE transfers_btc (
    id integer,
    trans character varying(64) NOT NULL,
    conf smallint DEFAULT 0 NOT NULL,
    address integer NOT NULL
);


ALTER TABLE public.transfers_btc OWNER TO exchange;

--
-- Name: TABLE transfers_btc; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE transfers_btc IS 'BTC transfers';


--
-- Name: COLUMN transfers_btc.trans; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN transfers_btc.trans IS 'Bitcoin transaction id';


--
-- Name: COLUMN transfers_btc.conf; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN transfers_btc.conf IS 'Confirmations';


--
-- Name: transfers_codes; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE transfers_codes (
    id integer NOT NULL,
    code character varying(52) NOT NULL,
    deposit_id integer
);


ALTER TABLE public.transfers_codes OWNER TO exchange;

--
-- Name: TABLE transfers_codes; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE transfers_codes IS 'Codes';


--
-- Name: COLUMN transfers_codes.deposit_id; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN transfers_codes.deposit_id IS 'Deposit transfer id of the code';


--
-- Name: transfers_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE transfers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transfers_id_seq OWNER TO exchange;

--
-- Name: transfers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE transfers_id_seq OWNED BY transfers.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    email character varying(150) NOT NULL,
    password character varying(52) NOT NULL,
    dt time without time zone NOT NULL,
    currency smallint NOT NULL
);


ALTER TABLE public.users OWNER TO exchange;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE users IS 'user accounts';


--
-- Name: users_btc; Type: TABLE; Schema: public; Owner: exchange; Tablespace: 
--

CREATE TABLE users_btc (
    id integer NOT NULL,
    address character varying(34) NOT NULL,
    users integer NOT NULL,
    dt timestamp without time zone NOT NULL
);


ALTER TABLE public.users_btc OWNER TO exchange;

--
-- Name: TABLE users_btc; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE users_btc IS 'Addresses of users';


--
-- Name: COLUMN users_btc.address; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN users_btc.address IS 'Bitcoin Address';


--
-- Name: users_btc_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE users_btc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_btc_id_seq OWNER TO exchange;

--
-- Name: users_btc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE users_btc_id_seq OWNED BY users_btc.id;


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO exchange;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY fees ALTER COLUMN id SET DEFAULT nextval('fees_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_limit ALTER COLUMN id SET DEFAULT nextval('orders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_stop ALTER COLUMN id SET DEFAULT nextval('orders_stop_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY symbols ALTER COLUMN id SET DEFAULT nextval('symbols_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY transfers ALTER COLUMN id SET DEFAULT nextval('transfers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY users_btc ALTER COLUMN id SET DEFAULT nextval('users_btc_id_seq'::regclass);


--
-- Name: balances_user_symbol_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY balances
    ADD CONSTRAINT balances_user_symbol_key UNIQUE (users, symbol);


--
-- Name: fees_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY fees
    ADD CONSTRAINT fees_pkey PRIMARY KEY (id);


--
-- Name: matched_buy_sell_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY matched
    ADD CONSTRAINT matched_buy_sell_key UNIQUE (buy, sell);


--
-- Name: orders_id_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY orders_limit
    ADD CONSTRAINT orders_id_key UNIQUE (id);


--
-- Name: orders_stop_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY orders_stop
    ADD CONSTRAINT orders_stop_pkey PRIMARY KEY (id);


--
-- Name: symbols_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY symbols
    ADD CONSTRAINT symbols_pkey PRIMARY KEY (id);


--
-- Name: symbols_symbol_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY symbols
    ADD CONSTRAINT symbols_symbol_key UNIQUE (symbol);


--
-- Name: transfers_btc_id_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY transfers_btc
    ADD CONSTRAINT transfers_btc_id_key UNIQUE (id);


--
-- Name: transfers_btc_trans_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY transfers_btc
    ADD CONSTRAINT transfers_btc_trans_key UNIQUE (trans);


--
-- Name: transfers_codes_code_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY transfers_codes
    ADD CONSTRAINT transfers_codes_code_key UNIQUE (code);


--
-- Name: transfers_codes_deposit_id_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY transfers_codes
    ADD CONSTRAINT transfers_codes_deposit_id_key UNIQUE (deposit_id);


--
-- Name: transfers_codes_id_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY transfers_codes
    ADD CONSTRAINT transfers_codes_id_key UNIQUE (id);


--
-- Name: transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY transfers
    ADD CONSTRAINT transfers_pkey PRIMARY KEY (id);


--
-- Name: users_btc_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY users_btc
    ADD CONSTRAINT users_btc_pkey PRIMARY KEY (id);


--
-- Name: users_email_key; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: i_ol_dt; Type: INDEX; Schema: public; Owner: exchange; Tablespace: 
--

CREATE INDEX i_ol_dt ON orders_limit USING btree (dt);


--
-- Name: i_users; Type: INDEX; Schema: public; Owner: exchange; Tablespace: 
--

CREATE INDEX i_users ON orders_limit USING btree (users);


--
-- Name: i_users2; Type: INDEX; Schema: public; Owner: exchange; Tablespace: 
--

CREATE INDEX i_users2 ON orders_stop USING btree (users);


--
-- Name: t_balance; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_balance AFTER INSERT ON users FOR EACH ROW EXECUTE PROCEDURE t_balance_acc();


--
-- Name: t_new_addr; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_new_addr BEFORE INSERT ON users_btc FOR EACH ROW EXECUTE PROCEDURE t_usr_btc_new();


--
-- Name: t_new_order; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_new_order AFTER INSERT ON orders_limit FOR EACH ROW EXECUTE PROCEDURE t_order_match();


--
-- Name: t_trans_btc; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_trans_btc AFTER UPDATE ON transfers_btc FOR EACH ROW EXECUTE PROCEDURE btc_trans_conf();


--
-- Name: t_upd_balance; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_upd_balance AFTER UPDATE ON balances FOR EACH ROW EXECUTE PROCEDURE t_upd_balance();


--
-- Name: t_upd_stopout; Type: TRIGGER; Schema: public; Owner: exchange
--

CREATE TRIGGER t_upd_stopout AFTER UPDATE ON symbols FOR EACH ROW EXECUTE PROCEDURE t_stopout();


--
-- Name: balances_symbol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY balances
    ADD CONSTRAINT balances_symbol_fkey FOREIGN KEY (symbol) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: balances_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY balances
    ADD CONSTRAINT balances_user_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matched_buy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY matched
    ADD CONSTRAINT matched_buy_fkey FOREIGN KEY (buy) REFERENCES orders_limit(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matched_sell_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY matched
    ADD CONSTRAINT matched_sell_fkey FOREIGN KEY (sell) REFERENCES orders_limit(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_limit_symbol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_limit
    ADD CONSTRAINT orders_limit_symbol_fkey FOREIGN KEY (symbol) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_limit_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_limit
    ADD CONSTRAINT orders_limit_users_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_stop_symbol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_stop
    ADD CONSTRAINT orders_stop_symbol_fkey FOREIGN KEY (symbol) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: orders_stop_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY orders_stop
    ADD CONSTRAINT orders_stop_users_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transfers_btc_address_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY transfers_btc
    ADD CONSTRAINT transfers_btc_address_fkey FOREIGN KEY (address) REFERENCES users_btc(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transfers_btc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY transfers_btc
    ADD CONSTRAINT transfers_btc_id_fkey FOREIGN KEY (id) REFERENCES transfers(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transfers_codes_deposit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY transfers_codes
    ADD CONSTRAINT transfers_codes_deposit_id_fkey FOREIGN KEY (deposit_id) REFERENCES transfers(id);


--
-- Name: transfers_codes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY transfers_codes
    ADD CONSTRAINT transfers_codes_id_fkey FOREIGN KEY (id) REFERENCES transfers(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transfers_symbol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY transfers
    ADD CONSTRAINT transfers_symbol_fkey FOREIGN KEY (symbol) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transfers_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY transfers
    ADD CONSTRAINT transfers_users_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: users_btc_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY users_btc
    ADD CONSTRAINT users_btc_users_fkey FOREIGN KEY (users) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: users_currency_fkey; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_currency_fkey FOREIGN KEY (currency) REFERENCES symbols(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

