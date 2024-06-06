module higan_fun::manager_contract {
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::tx_context::{sender};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use kriya::spot_dex::{create_protocol_configs, ProtocolConfigs};

    use std::debug;
    use std::ascii;
    // use sui::math;
    use sui::event;

    //Error types
    const ENotEnoughSuiForCoinPurchase: u64 = 0;
    const ETokenNotOpenForBuySell: u64 = 1;
    const EInvalidOwner: u64 = 2;
    const EClosingNonPendingCoin: u64 = 3;
    const EInsufficientFeePayment: u64 = 4;
    const ENotEnoughToWithdraw: u64 = 5;

    const INITIAL_COIN_PRICE: u64 = 1_000; // 0.000001 SUI
    const PRICE_INCREASE_PER_COIN: u64 = 1; // w/ our linear bonding curve, increases the price by 1 mist for every token minted


    // Statuses for coin lifecycle
    const STATUS_OPEN: u64 = 0; // Coin is ready for buys/sells
    const STATUS_CLOSE_PENDING: u64 = 1; // Coin has hit target, but we haven't yet created the LP for it
    const STATUS_CLOSED: u64 = 2; // We have created the LP, burned the LP tokens, and the initial bonding curve is done

    public struct CoinSocialsUpdatedEvent has copy, drop {
        bonding_curve_id: ID,
        twitter_url: Url,
        telegram_url: Url,
        discord_url: Url,
        website_url: Url
    }

    public struct SwapEvent has copy, drop {
        bonding_curve_id: ID,
        is_buy: bool,
        sui_amount: u64,
        coin_amount: u64,
        coin_price: u64,
        total_sui_reserve: u64,
        total_supply: u64,
        account: address
    }
    public struct CoinStatusChangedEvent has copy, drop {
        bonding_curve_id: ID,
        old_status: u64,
        new_status: u64,
    }

    public struct BondingCurve<phantom T> has key {
        id: UID,
        treasury: TreasuryCap<T>,
        // Later we should support dynamic metadata, but for now lets use fields
        creator: address,
        publisher: address,
        telegram_url: Url,
        discord_url: Url,
        twitter_url: Url,
        website_url: Url,
        sui_coin_amount: Balance<SUI>,
        status: u64,
        target: u64, //Amount in MIST that when crossed closes the token

        // Copy fees from ManagementContractConfig on creation so the fees are locked when listed and can't be changed by updates to ManagementContractConfig
        list_fee: u64,
        trade_fee: u64,
        launch_fee: u64,
        nsfw: bool,
    }

    public struct PrepayForListingReceipt has key {
        id: UID,
        creator: address,
        name: String,
        symbol: String,
        description: String,
        decimals: u64,
        target: u64,
        icon_url: Url,
        website_url: Url,
        telegram_url: Url,
        discord_url: Url,
        twitter_url: Url,
        list_fee: u64,
        trade_fee: u64,
        launch_fee: u64,
    }

    public struct PrepayForListingEvent has copy, drop {
        receipt: ID
    }

    public struct ManagementContractConfig has key {
        id: UID,
        owner: address,
        list_fee: u64, // Fee that is paid to list the token w/ the management contract
        trade_fee: u64, // Fee, in percentage, that is skimmed off of each buy/sell order
        launch_fee: u64, // Fee for creating an LP on a DEX and adding the initial liquidity
        fees_collected: Balance<SUI> // Fees collected by the contract, can be withdrawn by holders of AdminCap
    }

    public struct AdminCap has key {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, ctx.sender());

        transfer::share_object(ManagementContractConfig {
            id: object::new(ctx),
            owner: ctx.sender(),
            list_fee: 5_000_000_000, //5 SUI
            trade_fee: 0, // 0%
            launch_fee: 0, // 0 SUI
            fees_collected: balance::zero<SUI>() // Fees collected by the contract, can be withdrawn by holders of AdminCap
        });
    }

    // Frontend calls this to trigger the backend to create the token on the user's behalf
    //TODO for right now, admin could manually refund user if backend is down. Later, this should return a receipt to the user that, 
    // should the backend be down, they can use to withdraw their fee after a cooldown period (1h) if the backend never created their token
    public fun prepare_to_list(self: &mut ManagementContractConfig, 
        payment: Coin<SUI>, 
        name: String, 
        symbol: String, 
        description: String, 
        target: u64, 
        icon_url: vector<u8>, 
        website_url: vector<u8>, 
        telegram_url: vector<u8>, 
        discord_url: vector<u8>, 
        twitter_url: vector<u8>, 
        ctx: &mut TxContext): PrepayForListingReceipt{
        
        assert!(coin::value(&payment) >= self.list_fee, EInsufficientFeePayment);
        //TODO we need to collect the launch fee here too? Or is that also going to be a percentage based fee?

        coin::put(&mut self.fees_collected, payment);
        let receipt = PrepayForListingReceipt{
            id: object::new(ctx),
            creator: ctx.sender(),
            name: name,
            symbol: symbol,
            description: description,
            decimals: 3,
            target: target,
            icon_url: url::new_unsafe(ascii::string(icon_url)),
            website_url: url::new_unsafe(ascii::string(website_url)),
            telegram_url: url::new_unsafe(ascii::string(telegram_url)),
            discord_url: url::new_unsafe(ascii::string(discord_url)),
            twitter_url: url::new_unsafe(ascii::string(twitter_url)),
            list_fee: self.list_fee,
            trade_fee: self.trade_fee,
            launch_fee: self.launch_fee,
        };
        event::emit(PrepayForListingEvent {
            receipt: object::id(&receipt)
        });
        receipt
        // transfer::transfer(receipt, self.owner);

        
    }
    // when the treasury cap is stored in the bonding curve, the bonding curve is the owner of the treasury cap?
    // therefore anyone can access to the treasury cap through the bonding curve?
    public fun list<T>(_: &AdminCap, 
    treasury_cap: TreasuryCap<T>,
    receipt: &PrepayForListingReceipt, 
    ctx: &mut TxContext) {
    // : BondingCurve<T> {
         transfer::share_object(BondingCurve<T> {
            id: object::new(ctx),
            treasury: treasury_cap,
            creator: receipt.creator,
            publisher: ctx.sender(),
            website_url: receipt.website_url,
            telegram_url: receipt.telegram_url,
            discord_url: receipt.discord_url,
            twitter_url: receipt.twitter_url,
            sui_coin_amount: balance::zero(),
            status: STATUS_OPEN,
            target: receipt.target, // TODO when you figure out how to populate creator, also populate this
            list_fee: receipt.target,
            trade_fee: receipt.target,
            launch_fee: receipt.target,
            nsfw: false,
        });
    }
    
    public fun buy_coins<T>(
        self: &mut BondingCurve<T>, payment: Coin<SUI>, coin_metadata: &CoinMetadata<T>, sui_metadata: &CoinMetadata<SUI>, mintAmount: u64, ctx: &mut TxContext
    ){
        //TODO: Later we want to return the token and the request here and consume in a PTB. For now this just mints inline for ease of use.
        // : (Token<COIN_EXAMPLE>, ActionRequest<COIN_EXAMPLE>){
        assert!(self.status == STATUS_OPEN, ETokenNotOpenForBuySell);
        assert!(coin::value(&payment) >= get_coin_buy_price(self, mintAmount), ENotEnoughSuiForCoinPurchase);

        let payment_amount = coin::value(&payment);

        coin::put(&mut self.sui_coin_amount, payment);

        coin::mint_and_transfer(&mut self.treasury, mintAmount, sender(ctx), ctx);

        let balance_after: u64 = balance::value<SUI>(&self.sui_coin_amount) + payment_amount;

        if(balance_after >= self.target){

            let pc = create_protocol_configs(
                200, // protocol_fee_percent_uc 200 = 2%
                300, // lp_fee_percent_uc 300 = 3%
                200, // protocol_fee_percent_stable 200 = 2%
                300, // lp_fee_percent_stable 300 = 3%
                true, // is_swap_enabled true = swaps are enabled
                true, // is_deposit_enabled true = deposits are enabled
                true, // is_withdraw_enabled true = withdrawals are enabled
                ctx.sender(), // admin ctx.sender() = admin is the transaction sender
                sui::table::new<address, bool>(ctx), // whitelisted_addresses vector::empty() = no whitelisted addresses
                ctx
            );

          
            kriya::spot_dex::create_pool_<T, SUI>(
               &pc,
                false,
                coin_metadata,
                sui_metadata,
                ctx
            );

            self.status = STATUS_CLOSE_PENDING;
            event::emit(CoinStatusChangedEvent {
                bonding_curve_id: object::id(self),
                old_status: STATUS_OPEN,
                new_status: STATUS_CLOSE_PENDING
            });
            // transfer::public_transfer(pc, self.publisher)
        };

        event::emit(SwapEvent {
            bonding_curve_id: object::id(self),
            is_buy: true,
            sui_amount: payment_amount,
            coin_amount: mintAmount,
            coin_price: get_coin_price(self),
            total_sui_reserve: self.sui_coin_amount.value(),
            total_supply: coin::total_supply(&self.treasury),
            account: ctx.sender()
        });
    }

    //TODO Later remove the below and return coin for PTB
    #[allow(lint(self_transfer))]
     public fun sell_coins<T>(
        self: &mut BondingCurve<T>, payment: Coin<T>, ctx: &mut TxContext
    ){
        assert!(self.status == STATUS_OPEN, ETokenNotOpenForBuySell);
        let sellPrice = get_coin_sell_price(self, coin::value(&payment));
        let coinAmountSold = coin::value(&payment);
        // Take sui from the balance of this contract
        let returnSui = coin::take(&mut self.sui_coin_amount, sellPrice, ctx);

        coin::burn(&mut self.treasury, payment);


        transfer::public_transfer(returnSui, ctx.sender());

        event::emit(SwapEvent {
            bonding_curve_id: object::id(self),
            is_buy: false,
            sui_amount: sellPrice,
            coin_amount: coinAmountSold,
            coin_price: get_coin_price(self),
            total_sui_reserve: self.sui_coin_amount.value(),
            total_supply: coin::total_supply(&self.treasury),
            account: ctx.sender()
        });
    }


    public fun get_sui_balance<T>(self: &BondingCurve<T>): u64 {
        self.sui_coin_amount.value()
    }

    public fun get_coin_total_supply<T>(self: &BondingCurve<T>): u64 {
        coin::total_supply(&self.treasury)
    }

    // Returns current price of the token based on the bonding curve
    public fun get_coin_price<T>(self: &BondingCurve<T>): u64 {
        let total_supply: u64 = coin::total_supply(&self.treasury);

        if (total_supply == 0) {
            // get initial price
            INITIAL_COIN_PRICE
        } else {
            ((PRICE_INCREASE_PER_COIN * total_supply) + INITIAL_COIN_PRICE)
        }
    }

    // Returns the amount in SUI a user must pay to buy some amount of the token
    public fun get_coin_buy_price<T>(self: &BondingCurve<T>, amount: u64): u64 {
        let s0: u64 = coin::total_supply(&self.treasury);
        let s1: u64 = s0 + amount;

        //Formula that considers integer division edge cases
        //m * (S1 * (S1 + 1) - S0 * (S0 + 1)) / 2 + b * (S1 - S0)
        let total_cost = (PRICE_INCREASE_PER_COIN * (s1 * (s1 + 1) - s0 * (s0 + 1)) / 2) + (INITIAL_COIN_PRICE * (s1 - s0));
        // let total_cost = (100 * (math::pow(s1, 2) - math::pow(s0, 2)) / 2) + (initialPrice * (s1 - s0));

        total_cost
    }

    // Returns the amount in SUI a user will receive for selling some amount of the token
    public fun get_coin_sell_price<T>(self: &BondingCurve<T>, amount: u64): u64 {
        
        let s0: u64 = coin::total_supply(&self.treasury);
        let s1: u64 = s0 - amount;

        //m * (S0 * (S0 + 1) - S1 * (S1 + 1)) / 2 + b * (S0 - S1)
        let total_cost = (PRICE_INCREASE_PER_COIN * (s0 * (s0 + 1) - s1 * (s1 + 1)) / 2) + (INITIAL_COIN_PRICE * (s0 - s1));

        total_cost
    }

    // We use web2 calls to create + manage the LP, once we're done we can close the token
    public fun close_coin_sales<T>( _: &AdminCap, self: &mut BondingCurve<T>, ctx: &mut TxContext){
        assert!(self.creator == ctx.sender(), EInvalidOwner);
        assert!(self.status == STATUS_CLOSE_PENDING, EClosingNonPendingCoin);
        self.status = STATUS_CLOSED;
        //TODO We need to transfer the treasury cap to the creator
        // transfer::public_transfer(self.treasury, self.creator);
        event::emit(CoinStatusChangedEvent {
            bonding_curve_id: object::id(self),
            old_status: STATUS_CLOSE_PENDING,
            new_status: STATUS_CLOSED
        });
    }

    // Gives the creator of the token the ability to update the token's social metadata
    public fun update_coin_metadata<T>(self: &mut BondingCurve<T>, website_url: Url, telegram_url: Url, discord_url: Url, twitter_url: Url,  ctx: &mut TxContext) {
        assert!(self.creator == ctx.sender(), EInvalidOwner);

        self.telegram_url = telegram_url;
        self.discord_url = discord_url;
        self.twitter_url = twitter_url;
        self.website_url = website_url;

        event::emit(CoinSocialsUpdatedEvent {
            bonding_curve_id: object::id(self),
            telegram_url: telegram_url,
            discord_url: discord_url,
            twitter_url: twitter_url,
            website_url: website_url,
        });
    }

    public fun update_fees(_: &AdminCap, self: &mut ManagementContractConfig, list_fee: u64, trade_fee: u64, launch_fee: u64, ctx: &mut TxContext) {
        self.list_fee = list_fee;
        self.trade_fee = trade_fee;
        self.launch_fee = launch_fee;
    }


    public fun withdraw_all(_: &AdminCap, self: &mut ManagementContractConfig, ctx: &mut TxContext) {
        let amount = balance::value<SUI>(&self.fees_collected);
        let withdrawSui = coin::take(&mut self.fees_collected, amount, ctx);
        transfer::public_transfer(withdrawSui, ctx.sender());
    }

    public fun withdraw_fees(_: &AdminCap, self: &mut ManagementContractConfig, amount: u64, ctx: &mut TxContext) {
        assert!(amount <= balance::value<SUI>(&self.fees_collected), ENotEnoughToWithdraw);
        let withdrawSui = coin::take(&mut self.fees_collected, amount, ctx);
        transfer::public_transfer(withdrawSui, ctx.sender());
    }


    public fun dump_self<T>(self: &BondingCurve<T>) {
        debug::print(self)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
