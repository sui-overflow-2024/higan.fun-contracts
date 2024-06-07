module higan_fun::coin_contract {
    use sui::coin::{Self};
    use sui::url;
    use std::ascii;
    // use std::string::{Self, String};

    public struct COIN_CONTRACT has drop {}

    fun init(witness: COIN_CONTRACT, ctx: &mut TxContext) {
        let icon_url = option::some(url::new_unsafe(ascii::string(b"COIN_METADATA_ICON_URL")));
        let (treasury_cap, coin_metadata) = coin::create_currency<COIN_CONTRACT>(witness, 3/*DECIMALS*/, b"COIN_METADATA_NAME", b"COIN_METADATA_SYMBOL", b"COIN_METADATA_DESCRIPTION", icon_url, ctx);
        transfer::public_freeze_object(coin_metadata);

        // create and share the CoinExampleStore
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }


    // public fun manager_contract_version(): String {
    //     return ascii::string(b"higan-dot-fun-0.1.0")
    // }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(COIN_CONTRACT {}, ctx)
    }
}
