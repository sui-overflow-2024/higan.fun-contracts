// #[test_only]
// module we_hate_the_ui_contracts::token_example_tests {
//     use we_hate_the_ui_contracts::token_example;
//     use we_hate_the_ui_contracts::token_example::TOKEN_EXAMPLE;
//     use sui::test_scenario::{Self, next_tx, ctx};
//     use sui::coin::{Coin, TreasuryCap};
    

//   #[test]
//   fun mint_burn() {
//     let addr1 = @0xA;
//     let addr2 = @0xB;
//     // Begins a multi-transaction scenario with addr1 as the sender
//     let mut scenario = test_scenario::begin(addr1);
//     // Mint 100 tokens to addr1
//     {
//         token_example::test_init(ctx(&mut scenario));
//     };
    
//     // Mint a `Coin<MANAGED>` object
//     next_tx(&mut scenario, addr1);
//     {
//         let mut treasurycap = test_scenario::take_from_sender<TreasuryCap<TOKEN_EXAMPLE>>(&scenario);
//         token_example::mint(&mut treasurycap, 100, addr1, test_scenario::ctx(&mut scenario));
//         test_scenario::return_to_address<TreasuryCap<TOKEN_EXAMPLE>>(addr1, treasurycap);
//     };

//     // Burn a `Coin<MANAGED>` object
//     next_tx(&mut scenario, addr1);
//     {
//         let coin = test_scenario::take_from_sender<Coin<TOKEN_EXAMPLE>>(&scenario);
//         let mut treasurycap = test_scenario::take_from_sender<TreasuryCap<TOKEN_EXAMPLE>>(&scenario);
//         token_example::burn(&mut treasurycap, coin);
//         test_scenario::return_to_address<TreasuryCap<TOKEN_EXAMPLE>>(addr1, treasurycap);
//     };

//     // Transfer TreasuryCap to addr2
//     next_tx(&mut scenario, addr1);
//     {
//         let mut treasurycap = test_scenario::take_from_sender<TreasuryCap<TOKEN_EXAMPLE>>(&scenario);
//         token_example::transfer_cap(treasurycap, addr2);
//     };

//      // check if addr2 can now mint coins w/ TreasuryCap
//     next_tx(&mut scenario, addr2);
//     {
//         let mut treasurycap = test_scenario::take_from_sender<TreasuryCap<TOKEN_EXAMPLE>>(&scenario);
//         token_example::mint(&mut treasurycap, 100, addr2, test_scenario::ctx(&mut scenario));
//         test_scenario::return_to_address<TreasuryCap<TOKEN_EXAMPLE>>(addr2, treasurycap);
//     };

//      // check if addr2 can now burn coins w/ TreasuryCap
//     next_tx(&mut scenario, addr2);
//     {
//         let coin = test_scenario::take_from_sender<Coin<TOKEN_EXAMPLE>>(&scenario);
//         let mut treasurycap = test_scenario::take_from_sender<TreasuryCap<TOKEN_EXAMPLE>>(&scenario);
//         token_example::burn(&mut treasurycap, coin);
//         test_scenario::return_to_address<TreasuryCap<TOKEN_EXAMPLE>>(addr2, treasurycap);
//     };       



//     test_scenario::end(scenario);  
//   }
// }