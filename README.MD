# Setup
Install Sui from source, https://docs.sui.io/guides/developer/getting-started/sui-install#install-sui-binaries-from-source

cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui move-analyzer sui-faucet sui-graphql-rpc sui-node  sui-tool

sui client new-address ed25519
sui client new-address ed25519

├─────────────────────┼────────────────────────────────────────────────────────────────────┼────────────────┤
│ modest-hypersthene  │ 0xb2720b42e26a7fc1eb555ecd154ef3dc2446f80c1f186af901cd38b842e52044 │                │
│ heuristic-dichroite │ 0xbf611b504dbe4d22a8c7ef39f4a221d8c5b66bc0d05e6d3400cae3851d2543dc │ *              │
╰─────────────────────┴────────────────────────────────────────────────────────────────────┴─────────────

sui client publish --gas-budget 200000000 ./sources/coin_example.move

sui client switch --address 0xbf611b504dbe4d22a8c7ef39f4a221d8c5b66bc0d05e6d3400cae3851d2543dc


# Generate coin template
The backend compiles the custom coin template to bytecode and deploys it. You can generate the template for this with `python3 ./generate_template.py`. This will create a coin_template.hs.move file at the root. Dump the contents of this file into the template in the backend.

# How to call a function that requires Sui (like minting tokens)
1. Call `sui client gas`, find some gasCoinId that has enough suiBalance to pay for the function call
2. Call this to split 1 Sui: `sui client split-coin --coin-id $GAS_COIN_ID --amounts 1000000000 --gas-budget 10000000` 
    1. To split 1 Sui: `sui client split-coin --coin-id $GAS_COIN_ID --amounts 1000000000 --gas-budget 10000000`
    2. To split 0.1 Sui: `sui client split-coin --coin-id $GAS_COIN_ID --amounts 100000000 --gas-budget 10000000`
3. Call `sui client gas` again, you should see an entry with a smaller suiBalance, this is the one you split. Record the address of that smaller balance as $PAYMENT_ID
4. When you call a function with a signature like this, you pass the $PAYMENT_ID to the Coin<SUI> parameter:
  `public fun buy_token(self: &mut TokenExampleStore, payment: Coin<SUI>, ctx: &mut TxContext){}`
# How to pay with a custom token
1. Find the token you want to pay with (the token that will be burned to sell) with `sui client balance --with-coins`
  1. `sui client gas` only shows Sui unfortunately
2. Split the token for payment: `sui client split-coin --coin-id $CUSTOM_COIN_ID --amounts 1000000000 --gas-budget 100000000`
  3. Currently the tokens created in the template are fixed to 9 decimals, so the above *should* split 1 token. If we support dynamic decimals later, you can look up a coin's decimals by looking at the metadata (look up the Store in the explorer, check "metadata" field)
3. Call `sui client balance --with-coins` again to find your split. Record the id of that smaller balance as $PAYMENT_ID
4. When you call a function with a signature like this, you pass the $PAYMENT_ID to the Coin<CustomToken> parameter:
  `public fun sell_coins(self: &mut CoinExampleStore payment: Coin<COIN_EXAMPLE>, ctx: &mut TxContext){}`

# Token + Coin example commands

## Deploy
Deploy: `sui client publish --gas-budget 200000000 ./sources/coin_example.move`
After deploying, copy the PackageID under "Published Objects:", and find ObjectID of TokenExampleStore and CoinExampleStore under "Created Objects:". Put these into environment variables: $PACKAGE_ID, $TOKEN_STORE_ID, and $COIN_STORE_ID.

## Buy tokens
1. (Optional) Switch to a different user, one that doesn't own the coin, to prove this function is public: 
  1. sui client addresses (<- copy an address from here)
  2. sui client switch --address $OTHER_ADDRESS
2. Buy tokens: `sui client call --package $PACKAGE_ID --module token_example --function "buy_token" --args $EXAMPLE_STORE_ID $PAYMENT_ID --gas-budget 10000000`

## Sell tokens
1. [Split coins for the custom token](#how-to-pay-with-a-custom-token)
2. `sui client call --package $PACKAGE_ID --module coin_example --function "sell_coins" --args $COIN_STORE_ID 0x175fd6dd98911743b3750563053b41a9cbacc2d0a3a7d07e4215aef369455dc8 --gas-budget 10000000`
# Test PTBs
Example PTBs can be found under [./typescript-scripts](./typescripts-scripts/)
1. In that directory, run `pnpm i`
2. Then: `npx ts-node $WHATEVER SCRIPT`


# ARCHIVE (ignore all below)

# Manager contract commands
sui client publish --gas-budget 200000000 ./sources/manager.move      

sui client call --function mint --module token_example --package 0xced9b4a21f7c6d0665650d0b7269ed9ea00cf65341fc24c040c495fca4fc9d9d --args 0x7f83667b5fb275396a9cc0a34803770fabc8e7a68f0d2fdec1160911b3ef1c8f 100 0xbf611b504dbe4d22a8c7ef39f4a221d8c5b66bc0d05e6d3400cae3851d2543dc --gas-budget 10000000

sui client call --package 0xced9b4a21f7c6d0665650d0b7269ed9ea00cf65341fc24c040c495fca4fc9d9d --module manager --function "buy_tokens" --args 0x7f83667b5fb275396a9cc0a34803770fabc8e7a68f0d2fdec1160911b3ef1c8f --type-args we_hate_the_ui_contracts::token_example::TOKEN_EXAMPLE --gas-budget 10000000  


sui client call --function mint --module token_example --package $TOKEN_ID --args $TREASURY_CAP_ID  100 $TARGET_ADDRESS --gas-budget 10000000 

sui client call --function transfer_cap --module token_example --package $TOKEN_ID --args $TREASURY_CAP $ADDRESS_TO_TRANSFER_TO --gas-budget 10000000
