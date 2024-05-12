Install Sui from source, https://docs.sui.io/guides/developer/getting-started/sui-install#install-sui-binaries-from-source

 cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui move-analyzer sui-faucet
sui-graphql-rpc sui-node  sui-tool

sui client new-address ed25519
sui client new-address ed25519

├─────────────────────┼────────────────────────────────────────────────────────────────────┼────────────────┤
│ modest-hypersthene  │ 0xb2720b42e26a7fc1eb555ecd154ef3dc2446f80c1f186af901cd38b842e52044 │                │
│ heuristic-dichroite │ 0xbf611b504dbe4d22a8c7ef39f4a221d8c5b66bc0d05e6d3400cae3851d2543dc │ *              │
╰─────────────────────┴────────────────────────────────────────────────────────────────────┴─────────────

sui client publish --gas-budget 200000000 ./sources/token_example.move

sui client call --function mint --module token_example --package $TOKEN_ID --args $TREASURY_CAP_ID  100 $TARGET_ADDRESS --gas-budget 10000000 

sui client call --function transfer_cap --module token_example --package $TOKEN_ID --args $TREASURY_CAP $ADDRESS_TO_TRANSFER_TO --gas-budget 10000000

sui client switch --address 0xbf611b504dbe4d22a8c7ef39f4a221d8c5b66bc0d05e6d3400cae3851d2543dc



# Manager contract commands
sui client publish --gas-budget 200000000 ./sources/manager.move      

sui client call --function mint --module token_example --package 0xced9b4a21f7c6d0665650d0b7269ed9ea00cf65341fc24c040c495fca4fc9d9d --args 0x7f83667b5fb275396a9cc0a34803770fabc8e7a68f0d2fdec1160911b3ef1c8f 100 0xbf611b504dbe4d22a8c7ef39f4a221d8c5b66bc0d05e6d3400cae3851d2543dc --gas-budget 10000000

sui client call --package 0xced9b4a21f7c6d0665650d0b7269ed9ea00cf65341fc24c040c495fca4fc9d9d --module manager --function "buy_tokens" --args 0x7f83667b5fb275396a9cc0a34803770fabc8e7a68f0d2fdec1160911b3ef1c8f --type-args we_hate_the_ui_contracts::token_example::TOKEN_EXAMPLE --gas-budget 10000000  


# How to call a function that requires Sui (like minting tokens)
1. Call `sui client gas`, find some gasCoinId that has enough suiBalance to pay for the function call
2. Call `sui client split-coin --coin-id $GAS_COIN_ID --amounts 1000000000 --gas-budget 10000000`
    1. To split 1 Sui: `sui client split-coin --coin-id $GAS_COIN_ID --amounts 10000000000 --gas-budget 10000000`
    2. To split 0.1 Sui: `sui client split-coin --coin-id $GAS_COIN_ID --amounts 1000000000 --gas-budget 10000000`
3. Call `sui client gas` again, you should see an entry with a smaller suiBalance, this is the one you split. Record the address of that smaller balance as $PAYMENT_ID
4. When you call a function with a signature like this, you pass the $PAYMENT_ID to the Coin<SUI> parameter:
  `public fun buy_token(self: &mut TokenExampleStore, payment: Coin<SUI>, ctx: &mut TxContext){}`