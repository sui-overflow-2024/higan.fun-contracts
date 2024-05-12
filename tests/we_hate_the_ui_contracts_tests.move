#[test_only]
module we_hate_the_ui_contracts::we_hate_the_ui_contracts_tests {
    // uncomment this line to import the module
    // use we_hate_the_ui_contracts::we_hate_the_ui_contracts;
    use we_hate_the_ui_contracts::token_example::{Self, TOKEN_EXAMPLE, TokenExampleStore};
    use sui::coin::{Coin, TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx};

    const ENotImplemented: u64 = 0;

    #[test]
    fun test_we_hate_the_ui_contracts() {
          // Initialize a mock sender address
        let addr1 = @0xA;
        // Begins a multi-transaction scenario with addr1 as the sender
        let mut scenario = test_scenario::begin(addr1);
        {
            token_example::test_init(ctx(&mut scenario));
        };
        next_tx(&mut scenario, addr1);
        {
            let mut tokenExampleStore = test_scenario::take_from_sender<TokenExampleStore>(&scenario);
            splitCoin
            test_scenario::split_coin(&mut tokenExampleStore, 100);
            token_example::buy_token(&mut tokenExampleStore, 100);
            managed::mint(&mut treasurycap, 100, addr1, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_address<TreasuryCap<MANAGED>>(addr1, treasurycap);
        };
        // Cleans up the scenario object
        test_scenario::end(scenario);  
        // pass
    }

    #[test, expected_failure(abort_code = we_hate_the_ui_contracts::we_hate_the_ui_contracts_tests::ENotImplemented)]
    fun test_we_hate_the_ui_contracts_fail() {
        abort ENotImplemented
    }
}