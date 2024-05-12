/*
 1. Deploy token contract: sui client publish --gas-budget 200000000 ./sources/unit3.move
 2. Go to explorer and get package ID + TreasuryCap (TreasuryCapability) ID. Package ID, if you can't find it in the explorer, is the first item under "Published Objects:" when you publish 
    export PACKAGE_ID=0xa437d0c615a8c230ea982acb20781e8dae88f40fd9b51ac4941afaf09edc1e6d
    export TREASURYCAP_ID=0x357613a26d5539af44db89244dfa3992554ea8fe7fc9553305033a160c4a2545
 3. sui client call --function mint --module unit3 --package $PACKAGE_ID --args $TREASURYCAP_ID <amount> <recipient_address> --gas-budget 10000000
*/
// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example coin with a trusted manager responsible for minting/burning (e.g., a stablecoin)
/// By convention, modules defining custom coin types use upper case names, in contrast to
/// ordinary modules, which use camel case.
module we_hate_the_ui_contracts::token_example {
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
    public struct TOKEN_EXAMPLE has drop {}
    
    // OTW, burned after the creator is set
    public struct SetCreatorCap has key {
        id: UID
    }

    public struct WithdrawCap has key {
        id: UID
    }

    #[allow(lint(coin_field))]
    /// Gems can be purchased through the `Store`.
    public struct TokenExampleStore has key {
        id: UID,
        /// The Treasury Cap for the in-game currency.
        token_example_treasury: TreasuryCap<TOKEN_EXAMPLE>,
        // Later we should support dynamic metadata, but for now lets use fields
        creator: address,
        discordUrl: String,
        twitterUrl: String,
        websiteUrl: String,
        sui_token_amount: Balance<SUI>,
        // whitepaperUrl: String,
    }

// The formula for a linear bonding curve is as follows:
// Price = m * Supply + b
// Where:
// Price is the current price of the token
// Supply is the current supply of the token
// m is the slope or price increment per token
// b is the y-intercept or the initial price when the supply is zero


    /// Register the managed currency to acquire its `TreasuryCap`. Because
    /// this is a module initializer, it ensures the currency only gets
    /// registered once.
    fun init(witness: TOKEN_EXAMPLE, ctx: &mut TxContext) {
        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, coin_metadata) = coin::create_currency<TOKEN_EXAMPLE>(witness, 2, b"TOKEN_EXAMPLE", b"XMP", b"", option::none(), ctx);
        transfer::public_freeze_object(coin_metadata);
        
        // Create a token policy that allows users to buy or sell the token
        let (mut policy, cap) = token::new_policy(&treasury_cap, ctx); //TODO not sure if mut is safe here

        token::allow(&mut policy, &cap, buy_action(), ctx);
        token::allow(&mut policy, &cap, token::spend_action(), ctx);

        // create and share the GemStore
        transfer::share_object(TokenExampleStore {
            id: object::new(ctx),
            token_example_treasury: treasury_cap,
            creator: ctx.sender(),
            discordUrl: string::utf8(b""),
            twitterUrl: string::utf8(b""),
            websiteUrl: string::utf8(b""),
            sui_token_amount: balance::zero(),
            // whitepaperUrl: String::from(""),
        });

        // deal with `TokenPolicy`, `CoinMetadata` and `TokenPolicyCap`
        transfer::public_transfer(cap, sender(ctx));
        token::share_policy(policy);
    }

    /// Manager can mint new coins
    public fun mint(
        treasury_cap: &mut TreasuryCap<TOKEN_EXAMPLE>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    /// Manager can burn coins
    public fun burn(treasury_cap: &mut TreasuryCap<TOKEN_EXAMPLE>, coin: Coin<TOKEN_EXAMPLE>) {
        coin::burn(treasury_cap, coin);
    }

    // Manager will eventually transfer the treasury cap to the creator
    public fun transfer_cap(treasury_cap: TreasuryCap<TOKEN_EXAMPLE>, target: address){
        //I'm not positive this is secure, in theory: There is only one treasury cap, the person who called init has it, 
        // so the only person who should be able to transfer it in the person who called init?
        transfer::public_transfer(treasury_cap, target);
    }

    /// The name of the `buy` action in the `ExampleTokenStore`.
    public fun buy_action(): String { string::utf8(b"buy_token") }
    public fun buy_token(
        self: &mut TokenExampleStore, payment: Coin<SUI>, ctx: &mut TxContext
    ): (Token<TOKEN_EXAMPLE>, ActionRequest<TOKEN_EXAMPLE>){
        //TODO: Decimals on the token is hardcoded to 2 here
        // TODO Below is temporary, 
        
        let mintAmount = coin::value(&payment) * 10; // 0.1 SUI per token, fixed price initially 
        debug::print(&mintAmount);

        coin::put(&mut self.sui_token_amount, payment);
    
        let new_tokens = token::mint(&mut self.token_example_treasury, mintAmount, ctx);
        let req = token::new_request(buy_action(), mintAmount, option::none(), option::none(), ctx);
        (new_tokens, req)
    }
    public fun sell_action(): String { string::utf8(b"sell_token") }
    public fun dump_self(self: &TokenExampleStore) {
        debug::print(self)
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        
        init(TOKEN_EXAMPLE {}, ctx)
    }
}

// Package ID: 0x86d1a481d7fa520140a0dbb57f7932168d26f0cc385510900a645530d1ef835f
// TokenExampleStore: 0x419c2a570e60fff2b68bc90e04cc5a00db048675b18de351b06a15251d8d93b3
// TokenPolicyCap: 0xdc4775481595316fbe736318376c78fc7dfb026262884cc4408149e522e446e7