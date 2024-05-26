module we_hate_the_ui_contracts::coin_example {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{sender};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::url;
    use std::string::{Self, String};
    use std::debug;
    use std::ascii;
    // use sui::math;
    use sui::event;

    const ENotEnoughSuiForCoinPurchase: u64 = 0;
    const ETokenNotOpenForBuySell: u64 = 1;
    const ETokenAlreadyInitialized: u64 = 2;
    const EInvalidOwner: u64 = 3;
    const EValMustBeGreaterThanZero: u64 = 4;
    const EClosingNonPendingCoin: u64 = 5;

    #[allow(unused_const)]
    const POINT_ZERO_ONE_SUI: u64 = 10_000_000; //0.01 SUI
    #[allow(unused_const)]
    const POINT_ONE_SUI: u64 = 100_000_000; //0.1 SUI
    #[allow(unused_const)]
    const ONE_SUI: u64 = 1_000_000_000; //1 SUI
    const PRICE_INCREASE_PER_COIN: u64 = 1; // INCREASE PRICE BY ONE MIST PER COIN MINTED
    const INITIAL_COIN_PRICE: u64 = 1_000; // 0.000001 SUI

    // Statuses for coin lifecycle
    const STATUS_STARTING_UP: u64 = 0; // Coin has been created, but we need to do a follow up call to init metadata
    const STATUS_OPEN: u64 = 1; // Coin is ready for buys/sells
    const STATUS_CLOSE_PENDING: u64 = 2; // Coin has hit target, but we haven't yet created the LP for it
    const STATUS_CLOSED: u64 = 3; // We have created the LP, burned the LP tokens, and the initial bonding curve is done

    /// Note: For some reason the OTW has to be named the same as the address
    public struct COIN_EXAMPLE has drop {}

    // OTW, burned after the creator is set
    public struct SetCriticalMetadataCap has key {
        id: UID
    }

    public struct WithdrawCap has key {
        id: UID
    }

    public struct CoinSocialsUpdatedEvent has copy, drop {
        coin_store_id: ID,
        twitter_url: String,
        telegram_url: String,
        discord_url: String,
        website_url: String,
        sender: address
    }

    public struct SwapEvent has copy, drop {
        is_buy: bool,
        sui_amount: u64,
        coin_amount: u64,
        account: address
    }
    public struct CoinStatusChangedEvent has copy, drop {
        old_status: u64,
        new_status: u64,
    }

    // #[allow(lint(coin_field))]
    public struct CoinExampleStore has key {
        id: UID,
        treasury: TreasuryCap<COIN_EXAMPLE>,
        // Later we should support dynamic metadata, but for now lets use fields
        creator: address,
        publisher: address,
        telegram_url: String,
        discord_url: String,
        twitter_url: String,
        website_url: String,
        sui_coin_amount: Balance<SUI>,
        status: u64,
        target: u64 //Amount in MIST that when crossed closes the token
    }

    fun init(witness: COIN_EXAMPLE, ctx: &mut TxContext) {
        let iconUrl = option::some(url::new_unsafe(ascii::string(b"COIN_METADATA_ICON_URL")));
        let (treasury_cap, coin_metadata) = coin::create_currency<COIN_EXAMPLE>(witness, 3, b"COIN_METADATA_NAME", b"COIN_METADATA_SYMBOL", b"COIN_METADATA_DESCRIPTION", iconUrl, ctx);
        transfer::public_freeze_object(coin_metadata);

        // create and share the CoinExampleStore
        transfer::share_object(CoinExampleStore {
            id: object::new(ctx),
            treasury: treasury_cap,
            creator: ctx.sender(), //TODO Figure out how to populate this in the template
            publisher: ctx.sender(),
            website_url: string::utf8(b"OPTIONAL_METADATA_WEBSITE_URL"),
            telegram_url: string::utf8(b"OPTIONAL_METADATA_TELEGRAM_URL"),
            discord_url: string::utf8(b"OPTIONAL_METADATA_DISCORD_URL"),
            twitter_url: string::utf8(b"OPTIONAL_METADATA_TWITTER_URL"),
            sui_coin_amount: balance::zero(),
            status: STATUS_STARTING_UP,
            target: 0 // TODO when you figure out how to populate creator, also populate this
        });

        transfer::transfer(SetCriticalMetadataCap {
            id: object::new(ctx)
        }, ctx.sender());
    }

    // Manager will eventually transfer the treasury cap to the creator
    public fun transfer_cap(treasury_cap: TreasuryCap<COIN_EXAMPLE>, target: address){
        //I'm not positive this is secure, in theory: There is only one treasury cap, the person who called init has it,
        // so the only person who should be able to transfer it in the person who called init?
        transfer::public_transfer(treasury_cap, target);
    }

    public fun buy_coins(
        self: &mut CoinExampleStore, payment: Coin<SUI>, mintAmount: u64, ctx: &mut TxContext
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
            self.status = STATUS_CLOSE_PENDING;
            event::emit(CoinStatusChangedEvent {
                old_status: STATUS_OPEN,
                new_status: STATUS_CLOSE_PENDING
            });
        };

        event::emit(SwapEvent {
            is_buy: true,
            sui_amount: payment_amount,
            coin_amount: mintAmount,
            account: ctx.sender()
        });
    }

    //TODO Later remove the below and return coin for PTB
    #[allow(lint(self_transfer))]
     public fun sell_coins(
        self: &mut CoinExampleStore, payment: Coin<COIN_EXAMPLE>, ctx: &mut TxContext
    ){
        assert!(self.status == STATUS_OPEN, ETokenNotOpenForBuySell);
        let burnAmount = coin::value(&payment);

        // Take sui from the balance of this contract
        let returnSui = coin::take(&mut self.sui_coin_amount, burnAmount, ctx);

        coin::burn(&mut self.treasury, payment);


        event::emit(SwapEvent {
            is_buy: false,
            sui_amount: returnSui.value(),
            coin_amount: burnAmount,
            account: ctx.sender()
        });

        transfer::public_transfer(returnSui, ctx.sender())
    }


    public fun get_sui_balance(self: &CoinExampleStore): u64 {
        self.sui_coin_amount.value()
    }

    // Returns current price of the token based on the bonding curve
    public fun get_coin_price(self: &CoinExampleStore): u64 {
        let total_supply: u64 = coin::total_supply(&self.treasury);

        if (total_supply == 0) {
            // get initial price
            INITIAL_COIN_PRICE
        } else {
            ((PRICE_INCREASE_PER_COIN * total_supply) + INITIAL_COIN_PRICE)
        }
    }

    // Returns the amount in SUI a user must pay to buy some amount of the token
    public fun get_coin_buy_price(self: &CoinExampleStore, payment: u64): u64 {
        let s0: u64 = coin::total_supply(&self.treasury);
        let s1: u64 = s0 + payment;

        //Formula that considers integer division edge cases
        //m * (S1 * (S1 + 1) - S0 * (S0 + 1)) / 2 + b * (S1 - S0)
        let total_cost = (PRICE_INCREASE_PER_COIN * (s1 * (s1 + 1) - s0 * (s0 + 1)) / 2) + (INITIAL_COIN_PRICE * (s1 - s0));
        // let total_cost = (100 * (math::pow(s1, 2) - math::pow(s0, 2)) / 2) + (initialPrice * (s1 - s0));

        total_cost
    }

    // Returns the amount in SUI a user will receive for selling some amount of the token
    public fun get_coin_sell_price(self: &CoinExampleStore, payment: u64): u64 {
        let s0: u64 = coin::total_supply(&self.treasury);
        let s1: u64 = s0 - payment;

        //m * (S0 * (S0 + 1) - S1 * (S1 + 1)) / 2 + b * (S0 - S1)
        let total_cost = (PRICE_INCREASE_PER_COIN * (s0 * (s0 + 1) - s1 * (s1 + 1)) / 2) + (INITIAL_COIN_PRICE * (s0 - s1));

        total_cost
    }

    // Set the critical metadata for the coin, creator and target
    // TODO, we have logic here to make sure this only gets called once, but really we want to burn the cap and check that the cap is burned before engaging w/ the token
    public fun set_critical_metadata(self: &mut CoinExampleStore, _: &mut SetCriticalMetadataCap, target: u64, creator: address){
        assert!(self.status == STATUS_STARTING_UP, ETokenAlreadyInitialized);
        assert!(target > 0, EValMustBeGreaterThanZero);
        self.target = target;
        self.creator = creator;
        self.status = STATUS_OPEN;
        event::emit(CoinStatusChangedEvent {
            old_status: STATUS_STARTING_UP,
            new_status: STATUS_OPEN
        });
    }

    // We use web2 calls to create + manage the LP, once we're done we can close the token
    public fun close_coin_sales(self: &mut CoinExampleStore, _: &SetCriticalMetadataCap, ctx: &mut TxContext){
        assert!(self.creator == ctx.sender(), EInvalidOwner);
        assert!(self.status == STATUS_CLOSE_PENDING, EClosingNonPendingCoin);
        self.status = STATUS_CLOSED;
        //TODO We need to transfer the treasury cap to the creator
        // transfer::public_transfer(self.treasury, self.creator);
        event::emit(CoinStatusChangedEvent {
            old_status: STATUS_CLOSE_PENDING,
            new_status: STATUS_CLOSED
        });
    }

    public fun set_coin_social_metadata(self: &mut CoinExampleStore, telegram_url: String, discord_url: String, twitter_url: String, website_url: String, ctx: &mut TxContext) {
        //TODO Code smell, with this block we MUST update socials before setting critical metadata, since crit metadata updates creator
        assert!(self.creator == ctx.sender(), EInvalidOwner);

        self.telegram_url = telegram_url;
        self.discord_url = discord_url;
        self.twitter_url = twitter_url;
        self.website_url = website_url;

        event::emit(CoinSocialsUpdatedEvent {
            coin_store_id: object::id(self),
            telegram_url: telegram_url,
            discord_url: discord_url,
            twitter_url: twitter_url,
            website_url: website_url,
            sender: ctx.sender()
        });
    }


    public fun dump_self(self: &CoinExampleStore) {
        debug::print(self)
    }

    // BEGIN_TEST 
    // (leave above comment here as anchor to strip tests in template)
    #[test_only] use sui::test_scenario;
    #[test_only] use sui::test_utils;
    #[test]
    fun test_buy_price() {
          // Initialize a mock sender address
        let addr1 = @0xA;
        let creator = @0xB;
        // Begins a multi-transaction scenario with addr1 as the sender
        let mut scenario = test_scenario::begin(addr1);

        // scenario.next_tx(addr1);
        {
            init(COIN_EXAMPLE {}, scenario.ctx());
        };


        
        // Set critical metadata first
        test_scenario::next_tx(&mut scenario, addr1);
        {
            let mut coinExampleStore = test_scenario::take_shared<CoinExampleStore>(&scenario);
            let mut adminCap = test_scenario::take_from_sender<SetCriticalMetadataCap>(&scenario);
            
            assert!(coinExampleStore.status == STATUS_STARTING_UP);
            set_critical_metadata(&mut coinExampleStore, &mut adminCap, 10_000_000, creator); //One sui target, buy below will go over
            test_utils::assert_eq<u64>(coinExampleStore.status, STATUS_OPEN);
            test_utils::assert_eq<u64>(coinExampleStore.target, 10_000_000);
            test_utils::assert_eq<address>(coinExampleStore.creator, creator);
            test_scenario::return_shared(coinExampleStore);
            test_scenario::return_to_sender(&scenario, adminCap);
        };

        //Buy coins, starting with 1 ending with 100
        test_scenario::next_tx(&mut scenario, addr1);
        {
            let mut coinExampleStore = test_scenario::take_shared<CoinExampleStore>(&scenario);
            let adminCap = test_scenario::take_from_sender<SetCriticalMetadataCap>(&scenario);
        
            test_utils::assert_eq<u64>(get_coin_price(&coinExampleStore), 1_000);
            let buy1Price = get_coin_buy_price(&coinExampleStore, 1_000);
            debug::print(&string::utf8(b"buy1price"));
            debug::print(&buy1Price);
            test_utils::assert_eq<u64>(buy1Price, 1_500_500);
            let buy1coin = coin::mint_for_testing<SUI>(buy1Price, test_scenario::ctx(&mut scenario));
            
            buy_coins(&mut coinExampleStore, buy1coin, 1_000, test_scenario::ctx(&mut scenario));
            test_utils::assert_eq<u64>(coinExampleStore.status, STATUS_OPEN); //We haven't hit target, so we're still open
                

            let buy100Price = get_coin_buy_price(&coinExampleStore, 100_000);
            debug::print(&string::utf8(b"buy100price"));
            debug::print(&buy100Price);
            test_utils::assert_eq<u64>(buy100Price, 5_200_050_000);
            debug::print(&string::utf8(b"done"));
            let buy100coin = coin::mint_for_testing<SUI>(buy100Price, test_scenario::ctx(&mut scenario));
            buy_coins(&mut coinExampleStore, buy100coin, 100_000, test_scenario::ctx(&mut scenario));
            test_utils::assert_eq<u64>(coinExampleStore.status, STATUS_CLOSE_PENDING); //We hit target, coin should no longer be open for trades

            let reserve_balance = &coinExampleStore.sui_coin_amount;
            test_utils::assert_eq<u64>(reserve_balance.value(), buy1Price + buy100Price);
            test_utils::assert_eq<u64>(coin::total_supply(&coinExampleStore.treasury), 1_000 + 100_000);

            test_scenario::return_shared(coinExampleStore);
            test_scenario::return_to_sender(&scenario, adminCap);
        };
        // Cleans up the scenario object
        scenario.end();
    }

    #[test]
    // https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/test/test_scenario.move
    // https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/test/test_utils.move
    fun test_set_coin_metadata() {
        let addr1 = @0xA;
        // Begins a multi-transaction scenario with addr1 as the sender
        let mut scenario = test_scenario::begin(addr1);

        // scenario.next_tx(addr1);
        {
            init(COIN_EXAMPLE {}, scenario.ctx());
        };

      test_scenario::next_tx(&mut scenario, addr1);
      {
        let mut coinExampleStore = test_scenario::take_shared<CoinExampleStore>(&scenario);

        set_coin_social_metadata(&mut coinExampleStore, string::utf8(b"telegram_url"), string::utf8(b"discord_url"), string::utf8(b"twitter_url"), string::utf8(b"website_url"), scenario.ctx());

        test_utils::assert_eq<String>(coinExampleStore.telegram_url, string::utf8(b"telegram_url"));
        test_utils::assert_eq<String>(coinExampleStore.discord_url, string::utf8(b"discord_url"));
        test_utils::assert_eq<String>(coinExampleStore.twitter_url, string::utf8(b"twitter_url"));
        test_utils::assert_eq<String>(coinExampleStore.website_url, string::utf8(b"website_url"));

        test_scenario::return_shared<CoinExampleStore>(coinExampleStore);
      };

        scenario.end();
    }
    // (leave below comment here as anchor to strip tests in template)
    //END_TEST 
}
