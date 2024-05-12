/// Example coin with a trusted manager responsible for minting/burning (e.g., a stablecoin)
/// By convention, modules defining custom coin types use upper case names, in contrast to
/// ordinary modules, which use camel case.
module we_hate_the_ui_contracts::coin_example {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::transfer;
    use sui::tx_context::{Self, sender, TxContext};
    use sui::token::{Self, Token, ActionRequest}; // See here for the difference between coin and token: https://docs.sui.io/standards/closed-loop-token/coin-token-comparison
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use std::string::{Self, String};
    use std::debug;

    const POINT_ZERO_ONE_SUI: u64 = 10_000_000; //0.01 SUI
    const POINT_ONE_SUI: u64 = 100_000_000; //0.1 SUI
    const ONE_SUI: u64 = 1_000_000_000; //1 SUI

    /// Name of the coin. By convention, this type has the same name as its parent module
    /// and has no fields. The full type of the coin defined by this module will be `COIN<MANAGED>`.
    /// Note: For some reason the OTW has to be named the same as the address
    public struct COIN_EXAMPLE has drop {}
    
    // OTW, burned after the creator is set
    public struct SetCreatorCap has key {
        id: UID
    }

    public struct WithdrawCap has key {
        id: UID
    }

    // #[allow(lint(coin_field))]
    /// Gems can be purchased through the `Store`.
    public struct CoinExampleStore has key {
        id: UID,
        /// The Treasury Cap for the in-game currency.
        coin_example_treasury: TreasuryCap<COIN_EXAMPLE>,
        coin_example_metadata: CoinMetadata<COIN_EXAMPLE>,
        // coin_example_metadata: &CoinMetadata<COIN_EXAMPLE>,
        // Later we should support dynamic metadata, but for now lets use fields
        creator: address,
        discordUrl: String,
        twitterUrl: String,
        websiteUrl: String,
        sui_coin_amount: Balance<SUI>,
        // whitepaperUrl: String,
    }

    fun init(witness: COIN_EXAMPLE, ctx: &mut TxContext) {
        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, coin_metadata) = coin::create_currency<COIN_EXAMPLE>(witness, 2, b"COIN_EXAMPLE", b"XMP", b"", option::none(), ctx);
        // transfer::public_freeze_object(coin_metadata); //TODO There is a follow up function to seal properties on the token, don't forget to freeze the metadata at that time
        
        // create and share the CoinExampleStore
        transfer::share_object(CoinExampleStore {
            id: object::new(ctx),
            coin_example_treasury: treasury_cap,
            coin_example_metadata: coin_metadata,
            creator: ctx.sender(),
            discordUrl: string::utf8(b""),
            twitterUrl: string::utf8(b""),
            websiteUrl: string::utf8(b""),
            sui_coin_amount: balance::zero(),
            // whitepaperUrl: String::from(""),
        });

    }

    // Manager will eventually transfer the treasury cap to the creator
    public fun transfer_cap(treasury_cap: TreasuryCap<COIN_EXAMPLE>, target: address){
        //I'm not positive this is secure, in theory: There is only one treasury cap, the person who called init has it, 
        // so the only person who should be able to transfer it in the person who called init?
        transfer::public_transfer(treasury_cap, target);
    }

    public fun buy_coins(
        self: &mut CoinExampleStore, payment: Coin<SUI>, ctx: &mut TxContext
    ){
        //TODO: Later we want to return the token and the request here and consume in a PTB. For now this just mints inline for ease of use.
    // : (Token<COIN_EXAMPLE>, ActionRequest<COIN_EXAMPLE>){ 
        let source_decimals: u64 = 9;
        let target_decimals = self.coin_example_metadata.get_decimals() as u64;
        let mintAmount = (coin::value(&payment)*10^target_decimals)/(10^source_decimals); //TODO Risk of overflow at high values
    
        coin::put(&mut self.sui_coin_amount, payment);

        coin::mint_and_transfer(&mut self.coin_example_treasury, mintAmount, sender(ctx), ctx);
    }
    public fun sell_action(): String { string::utf8(b"sell_token") }
    public fun dump_self(self: &CoinExampleStore) {
        debug::print(self)
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {   
        init(COIN_EXAMPLE {}, ctx)
    }
}
