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
  url: getFullnodeUrl("testnet"),
});
(async () => {
  const config = loadConfigFromEnv();
  const txb = new TransactionBlock();

  // Withdraw the specified amount of SUI tokens from the user's account
  //   txb.moveCall({
  //     target: `0x2::coin::withdraw`,
  //     arguments: [txb.pure(amountToSend)],
  //     typeArguments: ["0x2::sui::SUI"],
  //   });

  // console.log("Splitting coins to pay for mint");
  // console.log("txb.gas: ", txb.gas);
  // I want to buy 100 tokens
  const buy100Price = txb.moveCall({
    target: `${config.managerContractId}::manager_contract::get_coin_buy_price`,
    arguments: [
      txb.object(config.bondingCurveId),
      txb.pure(100000), // 100,000 tokens in reality, looks like 100 tokens
    ],
    typeArguments: [
      `0xe31912ad16d0f6169ea4be7274d3af3d1f2659ab2c4c01a38785035b2b2d28d5::adipisci_abutor::ADIPISCI_ABUTOR`,
    ],
  });

  const [coinToSendToMint] = txb.splitCoins(txb.gas, [txb.object(buy100Price)]);
  // // // Call the `my_function` in the `my_module` module with the withdrawn SUI tokens

  // // console.log(coinToSendToMint);
  // // txb.transferObjects(
  // //   [coinToSendToMint],
  // //   // txb.pure(config.keyPair.toSuiAddress())
  // //   txb.pure(
  // //     "0xb2720b42e26a7fc1eb555ecd154ef3dc2446f80c1f186af901cd38b842e52044"
  // //   )
  // // );
  // // console.log("Calling buy_tokens");

  // // // // This will
  txb.moveCall({
    target: `${config.managerContractId}::manager_contract::buy_coins`,
    arguments: [
      txb.object(config.bondingCurveId),
      txb.object(config.kriyaProtocolConfigsId),
      txb.object(coinToSendToMint),
      txb.object(config.sourceCoinMetadataId),
      txb.object(config.suiCoinMetadataId),
      txb.pure(100_000),
      // txb.object(process.env.PAYMENT_ID || ""),
    ],
    typeArguments: [
      `${config.packageId}::${config.moduleName}::ADIPISCI_ABUTOR`,
    ],
  });

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
        showRawInput: true,
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
