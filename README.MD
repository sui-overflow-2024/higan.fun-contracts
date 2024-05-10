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

