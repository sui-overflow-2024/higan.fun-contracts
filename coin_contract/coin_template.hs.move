module higan_fun::{{name_snake_case}} {
    use sui::coin::{Self};
    use sui::url;
    use std::ascii;
    // use std::string::{Self, String};

    public struct {{name_snake_case_caps}} has drop {}

    fun init(witness: {{name_snake_case_caps}}, ctx: &mut TxContext) {
        let icon_url = option::some(url::new_unsafe(ascii::string(b"{{coin_metadata_icon_url}}")));
        let (treasury_cap, coin_metadata) = coin::create_currency<{{name_snake_case_caps}}>(witness, {{coin_metadata_decimals}}, b"{{name_snake_case_caps}}", b"{{coin_metadata_symbol}}", b"{{coin_metadata_description}}", icon_url, ctx);
        transfer::public_freeze_object(coin_metadata);

        // create and share the CoinExampleStore
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }


    // public fun manager_contract_version(): String {
    //     return ascii::string(b"higan-dot-fun-0.1.0")
    // }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init({{name_snake_case_caps}} {}, ctx)
    }
}
