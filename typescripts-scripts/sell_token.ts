import {
  TransactionArgument,
  TransactionBlock,
} from "@mysten/sui.js/transactions";
import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { fromB64 } from "@mysten/sui.js/utils";
import {
  decodeSuiPrivateKey,
  encodeSuiPrivateKey,
} from "@mysten/sui.js/cryptography";
import { loadConfigFromEnv } from "./util";

const client = new SuiClient({
  url: getFullnodeUrl("devnet"),
});
(async () => {
  // Convenience consts for the amount of SUI tokens to send (in MIST)
  const oneSui = 1_000_000_000; // 1 SUI = 1,000,000,000 MIST
  const pointOneSui = 100_000_000;
  const pointZeroOneSui = 10_000_000;
  const moduleName = "coin_example";

  const config = loadConfigFromEnv();
  const txb = new TransactionBlock();

  console.log("Splitting coins to pay for mint");
  console.log("txb.gas: ", txb.gas);
  console.log(
    "config.packageId",
    `${config.packageId}::${moduleName}::${moduleName.toUpperCase()}`
  );


  const sell100Amount = txb.moveCall({
    target: `${config.packageId}::${moduleName}::get_coin_sell_price`,
    arguments: [txb.object(config.storeId), txb.pure(100_000)],
  });
  const [coinToSendToMint] = txb.splitCoins(
    `${config.packageId}::${moduleName}::${moduleName.toUpperCase()}`,
    [txb.object(sell100Amount)]
  );

  txb.transferObjects(
    [coinToSendToMint],
    txb.pure(config.keyPair.toSuiAddress())
  );
  // console.log("Calling sell_coins");
  // // This will
  // txb.moveCall({
  //   target: `${config.packageId}::${moduleName}::sell_coins`,
  //   arguments: [
  //     txb.object(config.storeId),
  //     txb.object(coinToSendToMint),
  //     txb.pure(100_000)
  //     // txb.object(process.env.PAYMENT_ID || ""),
  //   ],
  // });

  // Sign and execute the transaction
  try {
    const response = await client.signAndExecuteTransactionBlock({
      transactionBlock: txb,
      signer: config.keyPair,
      requestType: "WaitForLocalExecution",
      options: {
        showBalanceChanges: true,
        showEffects: true,
        showEvents: true,
        showInput: true,
        showObjectChanges: true,
      },
    });
    console.log("Response: ", response);
  } catch (e) {
    console.error(e);
  }

  // txb.moveCall({
  //     target: "0x86d1a481d7fa520140a0dbb57f7932168d26f0cc385510900a645530d1ef835f::example_token::buy_token"
  //     arguments: [txb.pure.address("0x419c2a570e60fff2b68bc90e04cc5a00db048675b18de351b06a15251d8d93b3"), txb.mergeCoins]
  // })
})();
