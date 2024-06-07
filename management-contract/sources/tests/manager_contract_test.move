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
    use sui::coin::{Self, TreasuryCap, CoinMetadata};
    use sui::sui::SUI;
    use std::string::{Self};
    use std::vector;
    
    use higan_fun::manager_contract::{ManagementContractConfig};


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
            let admin_cap = test_scenario::take_from_sender<manager_contract::AdminCap>(&scenario);
            let mut management_contract_config = test_scenario::take_shared<ManagementContractConfig>(&scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<coin_contract_test::COIN_CONTRACT_TEST>>(&scenario);
            let metadata_in = test_scenario::take_immutable<CoinMetadata<coin_contract_test::COIN_CONTRACT_TEST>>(&scenario);
            let metadata_out = test_scenario::take_immutable<CoinMetadata<SUI>>(&scenario);
            let payment = coin::mint_for_testing<SUI>(5_000_000_000, test_scenario::ctx(&mut scenario));

            manager_contract::prepare_to_list(
                &mut management_contract_config,
                payment,
                string::utf8(b"COIN_METADATA_NAME"),
                string::utf8(b"COIN_METADATA_SYMBOL"),
                string::utf8(b"COIN_METADATA_DESC"),
                3, //decimals
                1_000_000_000, //target
                vector::empty<u8>(), //icon
                vector::empty<u8>(), //website
                vector::empty<u8>(), //telegram
                vector::empty<u8>(), //discord
                vector::empty<u8>(), //twitter
                test_scenario::ctx(&mut scenario)
            );
            let receipt = test_scenario::take_shared<manager_contract::PrepayForListingReceipt>(&scenario);
            manager_contract::list(&admin_cap, treasury_cap, &receipt, scenario.ctx());
            let mut bonding_curve = test_scenario::take_shared<manager_contract::BondingCurve<coin_contract_test::COIN_CONTRACT_TEST>>(&scenario);
            let buy_five_price = manager_contract::get_coin_buy_price(&bonding_curve, 100_000);
            let buy_payment = coin::mint_for_testing<SUI>(buy_five_price, test_scenario::ctx(&mut scenario));
            manager_contract::buy_coins<coin_contract_test::COIN_CONTRACT_TEST>(&mut bonding_curve, buy_payment, &metadata_in, &metadata_out, 100_000, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_to_sender(&scenario, receipt);
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(bonding_curve);
            test_scenario::return_immutable(management_contract_config);
            test_scenario::return_immutable(metadata_in);
            test_scenario::return_immutable(metadata_out);
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

