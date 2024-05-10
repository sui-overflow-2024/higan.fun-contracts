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
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Name of the coin. By convention, this type has the same name as its parent module
    /// and has no fields. The full type of the coin defined by this module will be `COIN<MANAGED>`.
    /// Note: For some reason the OTW has to be named the same as the address
    public struct TOKEN_EXAMPLE has drop {}

    /// Register the managed currency to acquire its `TreasuryCap`. Because
    /// this is a module initializer, it ensures the currency only gets
    /// registered once.
    fun init(witness: TOKEN_EXAMPLE, ctx: &mut TxContext) {
        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, metadata) = coin::create_currency<TOKEN_EXAMPLE>(witness, 2, b"TOKEN_EXAMPLE", b"XMP", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
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

    public fun transfer_cap(treasury_cap: TreasuryCap<TOKEN_EXAMPLE>, target: address){
        //I'm not positive this is secure, in theory: There is only one treasury cap, the person who called init has it, 
        // so the only person who should be able to transfer it in the person who called init?
        transfer::public_transfer(treasury_cap, target);
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        
        init(TOKEN_EXAMPLE {}, ctx)
    }
}