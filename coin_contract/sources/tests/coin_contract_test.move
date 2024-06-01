#[test_only]
module higan_fun::tests {

    use sui::coin::{Self, TreasuryCap};
    use sui::test_scenario;
    use higan_fun::coin_contract;

    #[test]
    fun test_creation() {
        // Initialize a mock sender address
        let addr1 = @0xA;
        // Begins a multi-transaction scenario with addr1 as the sender
        let mut scenario = test_scenario::begin(addr1);

        // scenario.next_tx(addr1);
        {
            coin_contract::init_for_testing(scenario.ctx());
        };

        scenario.next_tx(addr1);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<coin_contract::COIN_CONTRACT>>(&scenario);

            assert!(coin::total_supply(&treasury_cap) == 0, 1);

            test_scenario::return_to_sender(&scenario, treasury_cap);
        };

        test_scenario::end(scenario);
  }
}