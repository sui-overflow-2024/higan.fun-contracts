#[test_only]
module higan_fun::coin_contract_test {
    use sui::coin::{Self};
    use sui::url;
    use std::ascii;

    public struct COIN_CONTRACT_TEST has drop {}

    fun init(witness: COIN_CONTRACT_TEST, ctx: &mut TxContext) {
        let iconUrl = option::some(url::new_unsafe(ascii::string(b"COIN_METADATA_ICON_URL")));
        let (treasury_cap, coin_metadata) = coin::create_currency<COIN_CONTRACT_TEST>(witness, 3, b"COIN_METADATA_NAME", b"COIN_METADATA_SYMBOL", b"COIN_METADATA_DESCRIPTION", iconUrl, ctx);
        transfer::public_freeze_object(coin_metadata);

        // create and share the CoinExampleStore
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(COIN_CONTRACT_TEST {}, ctx)
    }
}

#[test_only]
module higan_fun::manager_contract_test {
    use higan_fun::manager_contract;
    use higan_fun::coin_contract_test;
    use sui::test_scenario;
    use sui::coin::{TreasuryCap};

   #[test]
    fun test_list() {
        // Initialize a mock sender address
        let addr1 = @0xA;
        let addr2 = @0xB;
        // Begins a multi-transaction scenario with addr1 as the sender
        let mut scenario = test_scenario::begin(addr1);

        {
            coin_contract_test::init_for_testing(scenario.ctx());
        };
        {
            manager_contract::init_for_testing(scenario.ctx());
        };

        scenario.next_tx(addr1);
        {
            let adminCap = test_scenario::take_from_sender<manager_contract::AdminCap>(&scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<coin_contract_test::COIN_CONTRACT_TEST>>(&scenario);

            manager_contract::list(&adminCap, treasury_cap, addr2, scenario.ctx());

            test_scenario::return_to_sender(&scenario, adminCap);
        };

        scenario.next_tx(addr1);
        {
            let bonding_curve = test_scenario::take_shared<manager_contract::BondingCurve<coin_contract_test::COIN_CONTRACT_TEST>>(&scenario);

            assert!(manager_contract::get_sui_balance(&bonding_curve) == 0, 1);
            assert!(manager_contract::get_coin_total_supply(&bonding_curve) == 0, 1);

            test_scenario::return_shared(bonding_curve);
        };

        scenario.end();
  }

}

