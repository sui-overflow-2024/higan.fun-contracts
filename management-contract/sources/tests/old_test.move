    // #[test]
    // fun test_buy_price() {
    //       // Initialize a mock sender address
    //     let addr1 = @0xA;
    //     let creator = @0xB;
    //     // Begins a multi-transaction scenario with addr1 as the sender
    //     let mut scenario = test_scenario::begin(addr1);

    //     // scenario.next_tx(addr1);
    //     {
    //         init(scenario.ctx());
    //     };

    //     // Set critical metadata first
    //     test_scenario::next_tx(&mut scenario, addr1);
    //     {
    //         let mut bondingCurve = test_scenario::take_shared<BondingCurve>(&scenario);
    //         let mut adminCap = test_scenario::take_from_sender<SetCriticalMetadataCap>(&scenario);

    //         test_utils::assert_eq<u64>(bondingCurve.status, STATUS_STARTING_UP);
    //         set_critical_metadata(&mut bondingCurve, &mut adminCap, 10_000_000, creator); //One sui target, buy below will go over
    //         test_utils::assert_eq<u64>(bondingCurve.status, STATUS_OPEN);
    //         test_utils::assert_eq<u64>(bondingCurve.target, 10_000_000);
    //         test_utils::assert_eq<address>(bondingCurve.creator, creator);
    //         test_scenario::return_shared(bondingCurve);
    //         test_scenario::return_to_sender(&scenario, adminCap);
    //     };

    //     //Buy coins, starting with 1 ending with 100
    //     test_scenario::next_tx(&mut scenario, addr1);
    //     {
    //         let mut coinExampleStore = test_scenario::take_shared<BondingCurve>(&scenario);
    //         let adminCap = test_scenario::take_from_sender<SetCriticalMetadataCap>(&scenario);

    //         test_utils::assert_eq<u64>(get_coin_price(&bondingCurve), 1_000);
    //         let buy1Price = get_coin_buy_price(&bondingCurve, 1_000);
    //         debug::print(&string::utf8(b"buy1price"));
    //         debug::print(&buy1Price);
    //         test_utils::assert_eq<u64>(buy1Price, 1_500_500);
    //         let buy1coin = coin::mint_for_testing<SUI>(buy1Price, test_scenario::ctx(&mut scenario));
    //         buy_coins(&mut coinExampleStore, buy1coin, 1_000, test_scenario::ctx(&mut scenario));
    //         test_utils::assert_eq<u64>(bondingCurve.status, STATUS_OPEN); //We haven't hit target, so we're still open

    //         let sell1Price = get_coin_sell_price(&bondingCurve, 1_000);
    //         debug::print(&string::utf8(b"sell1price"));
    //         debug::print(&sell1Price);
    //         test_utils::assert_eq<u64>(sell1Price, 1_500_500);
    //         //TODO Test sell_coins here

    //         let buy100Price = get_coin_buy_price(&coinExampleStore, 100_000);
    //         debug::print(&string::utf8(b"buy100price"));
    //         debug::print(&buy100Price);
    //         test_utils::assert_eq<u64>(buy100Price, 5_200_050_000);
    //         debug::print(&string::utf8(b"done"));
    //         let buy100coin = coin::mint_for_testing<SUI>(buy100Price, test_scenario::ctx(&mut scenario));
    //         buy_coins(&mut coinExampleStore, buy100coin, 100_000, test_scenario::ctx(&mut scenario));
    //         test_utils::assert_eq<u64>(coinExampleStore.status, STATUS_CLOSE_PENDING); //We hit target, coin should no longer be open for trades

    //         let reserve_balance = &coinExampleStore.sui_coin_amount;
    //         test_utils::assert_eq<u64>(reserve_balance.value(), buy1Price + buy100Price);
    //         test_utils::assert_eq<u64>(coin::total_supply(&coinExampleStore.treasury), 1_000 + 100_000);

    //         test_scenario::return_shared(coinExampleStore);
    //         test_scenario::return_to_sender(&scenario, adminCap);
    //     };
    //     // Cleans up the scenario object
    //     scenario.end();
    // }

    // #[test]
    // // https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/test/test_scenario.move
    // // https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/test/test_utils.move
    // fun test_set_coin_metadata() {
    //     let addr1 = @0xA;
    //     // Begins a multi-transaction scenario with addr1 as the sender
    //     let mut scenario = test_scenario::begin(addr1);

    //     // scenario.next_tx(addr1);
    //     {
    //         init(scenario.ctx());
    //     };

    //   test_scenario::next_tx(&mut scenario, addr1);
    //   {
    //     let mut bondingCurve = test_scenario::take_shared<BondingCurve>(&scenario);

    //     set_coin_social_metadata(&mut bondingCurve, string::utf8(b"telegram_url"), string::utf8(b"discord_url"), string::utf8(b"twitter_url"), string::utf8(b"website_url"), scenario.ctx());

    //     test_utils::assert_eq<String>(bondingCurve.telegram_url, string::utf8(b"telegram_url"));
    //     test_utils::assert_eq<String>(bondingCurve.discord_url, string::utf8(b"discord_url"));
    //     test_utils::assert_eq<String>(bondingCurve.twitter_url, string::utf8(b"twitter_url"));
    //     test_utils::assert_eq<String>(bondingCurve.website_url, string::utf8(b"website_url"));

    //     test_scenario::return_shared<BondingCurve>(bondingCurve);
    //   };

    //     scenario.end();
    // }